## Goals / Non-Goals

Goals: let an operator opt every long-running chart workload into a per-service PodDisruptionBudget and pod topology spread, in `src/groundx` and the `helm/` mirror identically, with zero render change when unset (see proposal.md for scope and blast radius).

Non-goals: the bundled Redis StatefulSets and the `schema-migration` Job; configurable `minAvailable`; a chart-injected `labelSelector`; a new CI step; harness documentation (separate repo).

## Decisions

**Invariant.** A service's PodDisruptionBudget selects exactly that service's own Deployment pods, so enabling one service's budget can never protect or block another. This is checked by the Deployment name used for `metadata.name` and `selector.matchLabels.app`, not by the settings key it came from: in `celery.yaml` the group variable `$svc` is `layout` while the Deployment is `$name` (`layout-map`), so `$name` is used there. The Celery test enables two workers in one group to catch the wrong variable.

**PDB block: repeated per renderer, not extracted.** The existing block is inline in `api.yaml` and `golang.yaml`. The new renderers (celery, metrics, inference) copy the same block with their own Deployment-name variable. Extracting a helper would touch the two working renderers for no behavior gain; api and golang output stays byte-identical.

**Spread: one new element helper.** `_helpers/elements/topologyspread.tpl` defines `groundx.renderTopologySpread` (args `ctx`, `indent`), placed beside `tolerations.tpl`. It emits nothing when the list is empty and otherwise `topologySpreadConstraints:` followed by the list via `toYaml`, unchanged. It is called next to `renderTolerations` in `api`, `golang`, `celery`, `metrics` and `inference`.

**Settings helpers.** Each of the per-service settings helpers in `_helpers/app/` passes `disruptionBudget` using the existing pattern (`"disruptionBudget" (dig "disruptionBudget" dict $in)`) and passes `topologySpreadConstraints` per key with `hasKey`; `large-file-deliver.tpl` adds it to its existing pass-through key list.

**Schema.** `disruptionBudget` is an object `{enabled: boolean}` with `additionalProperties: false`, and `topologySpreadConstraints` is `{type: array, items: {type: object}}`, added to each service. `workspace.cleanup`, `command`, `publish` and `workspace` reference `workspace.provision`; `workspace.api` is its own object. `values.yaml` gets `disruptionBudget: {enabled: false}` for the services gaining the budget, and no default for spread.

**Compatibility.** Additive and off by default: existing values files and snapshots are unaffected. No versioned mechanism is needed. Producer contract shapes are recorded in `contract.md` and confirmed at apply.

**Test economy and size.** Hand-written tests total about 105 lines: 88 appended to `src/groundx/tests/api_pdb_test.yaml` (one enabled case each for Go workers, Celery, metrics and inference, and one spread-only case for API and groundx) plus 17 in `helm/tests/drain_protection_test.yaml` (the only test on the mirror, run by the existing `helm unittest helm` step). No default-off cases: the existing default snapshots, with a zero `__snapshot__` diff, cover them. The mirror doubles the production diff, so the T1 size budget is expected to be exceeded and a composition waiver is expected.

**Snapshots.** Any snapshot diff is a bug. If `helm unittest -u` is ever needed, it goes in its own commit.

## Amendments

### 2026-09-30: replica-minimum warning and all-30 render guard

**Invariant.** A budget-on service is warned about exactly when its effective minimum replica count is below 2, where the minimum is `replicas.min` for a service in the chart's own autoscaled set (`groundx.hpa`, which is what `hpa.yaml` uses to decide) and `replicas.desired` otherwise. The minimum comes from each service's `groundx.<service>.settings` helper, so it is the same resolved value the Deployment and HorizontalPodAutoscaler render from.

**Warning, not failure.** `templates/NOTES.txt` prints one WARNING line per affected service. A `fail` would break installs that enable a budget today and work, and the reviewer marked the point non-blocking. The service list is the union of the chart's own renderer lists (`groundx.api.services`, `groundx.celery.process.services`, `groundx.golang.services`, `groundx.inference.services`) plus metrics, which is the 30 services that accept `disruptionBudget.enabled`. With no budget enabled the NOTES output is byte-identical to before.

**Guard.** `.build/bin/validate-helm.sh` gains one render check per chart surface with `--set` flags generated from an array of the 30 service keys (layered over `values.large-file.yaml`, which supplies the required delivery settings): exactly 30 PodDisruptionBudgets and 30 pod specs with `topologySpreadConstraints`. A missed pass-through in any renderer helper now fails the gate. The spread test fixtures gain a `labelSelector` on each service's `app` label so they are usable constraints.

Not in this amendment: `unhealthyPodEvictionPolicy: AlwaysAllow`, tracked in GX-84.

With these additions, hand-written tests total about 208 lines: 177 in `src/groundx/tests/api_pdb_test.yaml` and 31 in `helm/tests/drain_protection_test.yaml`.
