## Blast radius

**BREAKING for existing `mode: ingest` installs, chart-only, render-level.** No cluster is
touched by this change itself — this repo is `PRIVILEGED` and this change is templates, chart
test fixtures, and the build-time validation gate only; nothing here runs `helm upgrade` or any
deploy/publish command. The blast radius lands on the next `helm upgrade` a human operator runs,
against any cluster (dev/staging/prod, any of eks/aks/gke/openshift/minikube), for an install that
has `mode: ingest` set.

- Published chart `0.2.6` (`registry.groundx.ai/helm`, index created 2026-06-25) and the current
  unfixed `0.2.7` tip both carry the regression: under `mode: ingest`, `ranker-api` and
  `ranker-inference` render today even though the chart's own defaults (`ranker.api.enabled:
  true`, `ranker.inference.enabled: true`) were meant to be overridden by ingest-only mode.
- The first `helm upgrade` from either of those onto this fix **deletes** exactly these seven live
  objects in any existing `mode: ingest` install: `Deployment/ranker-api`,
  `Deployment/ranker-inference`, `Service/ranker-api` (there is no `ranker-inference` Service —
  `templates/app/inference.yaml` never calls `groundx.renderInterface`),
  `Secret/ranker-config-py-map` (renders `kind: Secret`, not `ConfigMap` — GX-17), and the two
  `ConfigMap`s `ranker-gunicorn-conf-py-map` and `ranker-inference-supervisord-conf-map`, plus the
  `PersistentVolumeClaim/ranker-model`. No `helm.sh/resource-policy: keep` exists on any of these
  objects.
- Deleting the `ranker-model` PVC deletes the PVC object itself; whether the **backing volume** is
  also reclaimed depends on the install's StorageClass `reclaimPolicy`
  (`terraform/aws/setup-eks:373` sets `Retain` for the EFS-backed class, `:387` sets `Delete` for
  the EBS-backed class). Under a `Delete`-reclaim class the PV and its backing volume are reclaimed
  automatically; under a `Retain`-reclaim class (e.g. the EFS path) the PV is only released, not
  deleted, and an operator on that path must delete the released PV manually or it is orphaned.
- The GPU model backing that PVC is re-downloadable from `upload.groundx.ai` at next pod start
  (once a new PVC is provisioned), so this is data cleanup rather than unrecoverable loss, but it
  is a real deletion an operator must be told about before they upgrade — **this needs a release
  note**, not just a changelog line, and the note must cover the `Retain`-reclaim orphaned-PV case
  above. The hand-off task list already carries this into the PR body and the 0.2.7 release notes.
- `mode: all` (the default) is unaffected: rendered output is byte-identical before and after,
  verified 2026-09-10 against the pre-fix and reference (`groundx.search.create`) branch shapes.
  Installs on `mode: all` see no behavior change and no destructive upgrade.

**Rollback/rollforward.** This is a template-only fix with no schema or migration step. Rollback
is `helm rollback` to the prior chart version, which re-creates the deleted ranker objects from
the previous release's manifest (image pulls + a fresh model download at pod start; no state was
preserved to restore). Rollforward is simply re-applying this chart version. No stateful-store
migration, no data backfill, and no coordinated multi-repo rollout — this is a single-repo,
single-level change (`groundx-on-prem` only; see `tasks.md`).

## Why

The harness (`skills/groundx-on-prem/references/deployment-modes.md`) tells operators that under
`mode: ingest` the ranker microservices auto-disable and explicitly instructs them **not** to set
`ranker.*.enabled: false`. Against the chart today, both statements are false: `ranker-api` and
`ranker-inference` still render, and `ranker-inference` carries a `eyelevel-gpu-ranker` node
affinity that a reasonable ingest-only deployment never provisions a node group for — so the pod
stays `Pending` forever. An operator who follows the harness's explicit guidance ends up stuck,
with the harness itself steering them away from the only working fix (`enabled: false`).

Root cause, verified against `origin/0.2.7` tip `b8e57f2d`: commit `e4319321` (2026-05-27,
"ranker deployment") swapped the branch order in both `groundx.ranker.api.create` and
`groundx.ranker.inference.create`, so the explicit-`enabled`-key check now runs *before* the
ingest-only-mode check. Because the chart ships `ranker.api.enabled: true` /
`ranker.inference.enabled: true` as defaults, the `hasKey $in "enabled"` branch is always true and
the ingest-only branch is unreachable dead code. The chart's own convention for this exact
tradeoff survives intact in a sibling helper, `groundx.search.create`
(`src/groundx/templates/_helpers/services/search.tpl:12-16`), which still tests mode before the
explicit key. Benjamin Fletcher confirmed (Linear comment, 2026-09-10, severity raised to High):
"Please restore previous logic/functionality. This was a regression added on May 27" — selecting
the chart fix over the alternative docs-only patch.

Nothing in `src/groundx/tests/` asserts ranker absence under `mode: ingest` — a
`mode: ingest` fixture exists and feeds 9 test suites, but three snapshot files simply froze the
regressed output as golden, which is why the reorder shipped and stayed undetected.

## What Changes

- **BREAKING** (existing `mode: ingest` installs only — see Blast radius): restore the
  pre-`e4319321` mode-first branch order in `groundx.ranker.api.create`
  (`src/groundx/templates/_helpers/app/ranker-api.tpl:13-24`) and
  `groundx.ranker.inference.create` (`ranker-inference.tpl:13-24`) — test
  `groundx.ingestOnly` **before** `hasKey $in "enabled"`, matching `groundx.search.create`. Under
  `mode: ingest`, an explicit `ranker.*.enabled: true` is now overridden by the mode (mode wins
  unconditionally); `mode: all` render output is unchanged.
- Apply the identical hunk to both chart mirrors: `src/groundx/templates/_helpers/app/` (source
  of truth) and `helm/templates/_helpers/app/` (published mirror) — the two files are
  byte-identical today, so the same 4-line swap applies cleanly to both.
- As a direct consequence of the restored ordering, `resources/hpa.yaml` stops rendering an HPA
  for `ranker.api` / `ranker.inference` under `mode: ingest` (HPA creation is keyed off the same
  `.create` helper — `_helpers/app/hpa.tpl:22-23`, `ranker-api.tpl:120-126`,
  `ranker-inference.tpl:103-109`). No template change is needed for this; it is covered by new
  test coverage (below), not a separate code change.
- Regenerate the five `src/groundx/tests/__snapshot__/*.snap` blocks that currently record the
  regression as golden (`api_test.yaml.snap`, `inference_test.yaml.snap`,
  `resources_test.yaml.snap`, `golang_test.yaml.snap`, `metrics_test.yaml.snap` — the last two
  hash the shared `resources/config-yaml.yaml` render into their `config-hash` annotation, so they
  also shift; see `design.md`'s "Snapshot regen scope" decision) via `helm unittest -u` scoped to
  those five files. The regenerated diff must touch **only** labels prefixed `extract:`,
  `extract.ingest:`, or `extract.oai:` (the three fixture families that set `mode: ingest`) — any
  other label changing is itself a defect (the `mode: all` byte-identical constraint).
- Add permanent `mode: ingest` coverage to `src/groundx/tests/ranker_test.yaml`: assert by
  **resource name**, not document count (a zero-document assertion on `templates/app/api.yaml` /
  `inference.yaml` is unsatisfiable — those templates also render extract/layout/summary
  services under `mode: ingest`) — no `ranker-api` or `ranker-inference` document renders while
  sibling api/inference services still do; a case proving an explicit `ranker.*.enabled: true` is
  overridden by the mode; and an HPA case (`cluster.hpa: true` + `mode: ingest` → no ranker HPA).
- Add a dual-surface ingest render guard to `.build/bin/validate-helm.sh`, following its existing
  `for chart in src/groundx helm; do` pattern: assert `helm template <chart> --set mode=ingest`
  renders no `ranker-api` / `ranker-inference` document and zero `eyelevel-gpu-ranker` occurrences,
  for **both** `src/groundx` and `helm`. This is the only mechanism that ever exercises the
  `helm/` mirror — it has no `tests/` tree (`.helmignore` excludes it from the package) and CI
  runs `helm unittest` against `src/groundx` alone.
- Annotate the now-inert `cluster.nodeLabels.gpuRanker: eyelevel-gpu-ranker` entry in place in
  `src/groundx/values/chainguard/values.yaml:55` and its `helm/` mirror (a bare deletion fails
  `helm lint`: `values.schema.json` marks all five `nodeLabels` keys `required` with
  `additionalProperties: false`, and relaxing that schema for a cosmetic cleanup was judged the
  worse trade — see `design.md`'s `nodeLabels`/schema decision). After this fix, nothing schedules
  to that node label under `mode: ingest`, so the entry is inert in this preset and the comment
  says why; `values.schema.json` is left untouched on both surfaces.

Known, out of scope (recorded, not fixed — see `design.md` and `AGENTS.md` "resolve from the docs
first"): `origin/main` (chart 0.2.6 release line) carries the identical regression and is not
touched here, per explicit direction; `_helpers/app/ingress.tpl:16` gates the ranker-api ingress
entry on `ranker.api.ingress.enabled` rather than on `groundx.ranker.api.create`, so an unusual
`mode: ingest` + ingress opt-in still renders a backend-less Ingress — a pre-existing shape shared
with `extract.api`/`layout.api`/`summary.api`, not introduced or widened by this change.

**Open design questions:** none — the fix shape, the assertion mechanism, the destructive-upgrade
disclosure, the harness-docs scope decision (no change needed; the harness statements become true
once this ships), and the out-of-scope items above were all resolved during decomposition
(`sdd-planner`, amendments A1-A8, human-approved at the plan gate).

## Capabilities

### New Capabilities

- `ranker-ingest-mode-gating`: the ranker microservices (`ranker.api`, `ranker.inference`) and
  their generated resources (Deployment, Service, ConfigMaps, HPA, node affinity/tolerations) do
  not render under `mode: ingest`, regardless of an explicit `ranker.*.enabled: true`, on both the
  `src/groundx` source chart and the `helm` publication mirror.

### Modified Capabilities

None. `openspec/specs/ranker-inference-autoscaling/spec.md` is the only existing spec touching
ranker inference, and every one of its scenarios preconditions "ranker inference is enabled" —
none of it asserts (or contradicts) mode-gating behavior, so no existing requirement changes.

## Impact

- **Code:** `src/groundx/templates/_helpers/app/ranker-api.tpl`,
  `.../ranker-inference.tpl`, and their byte-identical `helm/templates/_helpers/app/` mirrors;
  `src/groundx/tests/ranker_test.yaml`; the five
  `src/groundx/tests/__snapshot__/{api,inference,resources,golang,metrics}_test.yaml.snap` files
  (regenerated, never hand-edited — see "Snapshot regen scope" in `design.md`);
  `.build/bin/validate-helm.sh`; `src/groundx/values/chainguard/values.yaml` (annotated, not
  edited elsewhere — `values.schema.json` untouched) and its `helm/` mirror.
- **Dependencies / cross-repo:** none. `groundx-on-prem` has no in-tree code dependency on any
  other workspace repo; this ticket deliberately excludes the harness repos (`AGENTS.md`
  §Resolve-from-docs; decomposition A2).
- **Systems / data:** no schema or seed-data migration. The destructive-upgrade impact on a live
  `mode: ingest` install (the seven objects enumerated above under Blast radius, plus the
  `ranker-model` PVC's backing volume where the install's StorageClass reclaim policy is
  `Delete`) is a chart-render consequence surfaced above under Blast radius, not a database
  change — nothing here requires the pipeline's DB-migration gates.
- **Environments:** dev/staging/prod, all supported cluster types. No environment is redeployed
  by authoring this change; the risk activates only when a human runs `helm upgrade` against a
  `mode: ingest` install on an affected chart version, which the PR body and 0.2.7 release notes
  must disclose (carried in `tasks.md` hand-off).
