## Why

All five API-pod Deployments (`layout`, `extract`, `ranker`, `summary`, `workspace`) render their liveness and readiness `/health` probes from one template, `src/groundx/templates/app/api.yaml:142-154`, which sets neither probe's `timeoutSeconds`. Both therefore silently inherit Kubernetes' built-in 1-second timeout, and the readiness probe additionally has no explicit `failureThreshold`, so it inherits Kubernetes' built-in default of 3. A 1-second budget is not a realistic allowance for an HTTP health check that performs I/O, and neither value is exposed as a Helm value today — the only way to change it is a vendored-template patch or a Kustomize post-render patch. FRA-145's incident evidence shows this ceiling turning transient slowness into readiness-probe ejection and, after sustained failure, liveness-triggered pod restarts. This chart change makes both settings Helm-configurable, with defaults chosen to be strictly more forgiving than today's implicit behavior, so the platform is no longer pinned to Kubernetes' generic defaults for a check that does real work.

## What Changes

- Add a `timeoutSeconds` key to the liveness probe and to the readiness probe, and a `failureThreshold` key to the readiness probe, in the shared template `src/groundx/templates/app/api.yaml:142-154` that renders all five API-pod Deployments.
- Declare the new keys in each of the five per-service `*.api` schema blocks in `src/groundx/values.schema.json` (each is `additionalProperties: false`, so an undeclared key is rejected by `helm` rather than silently ignored) and thread them through the five per-service helpers `src/groundx/templates/_helpers/app/{extract,layout,ranker,summary,workspace}-api.tpl`.
- Set the shipped chart defaults in `src/groundx/values.yaml`: `timeoutSeconds: 3` on both probes, readiness `failureThreshold: 3` (liveness `failureThreshold` stays `12`, unchanged).
- Manually mirror the same template/schema/default changes into `helm/` (the manual, unguarded publication mirror of `src/groundx`) per this repo's existing sync convention.
- Regenerate the affected `helm-unittest` snapshots (`src/groundx/tests/__snapshot__/{api,ranker,workspace}_test.yaml.snap`) as their own commit hunk, separate from the template/schema edit, so the behavioral diff stays readable.
- No application code changes in this repo — this is a chart-only, config-surface change. It touches only the four files/dirs above; the served `/health` handler, its response shape, and its status code are unchanged (see `contract.md`; the ai-server side of FRA-145 is a separate, same-level change).

**BREAKING**: none. Both new keys are additive to the values schema (new optional keys with defaults, not a shape change to an existing key), and the readiness-probe default (`failureThreshold: 3`) reproduces today's effective Kubernetes-default behavior exactly. The liveness/readiness `timeoutSeconds: 3` default does change effective behavior for every existing deployment on `helm upgrade` (see Impact) — always in the more-forgiving direction, so it can loosen an ejection/restart trigger, never introduce a new one.

## Capabilities

### New Capabilities
- `api-probe-timing`: Helm-configurable `timeoutSeconds` (liveness and readiness) and readiness `failureThreshold` for the five API-pod Deployments' `/health` probes, with defaults that preserve or loosen today's effective probe behavior.

### Modified Capabilities
(none — no existing `openspec/specs/*` capability documents probe timing; `deployment-config` and `values-contract-semantics` cover unrelated value blocks.)

## Impact

**Affected code** (all in `groundx-on-prem`, base `0.2.7`):
- `src/groundx/templates/app/api.yaml:142-154` — the one template rendering all five API-pod liveness/readiness probes.
- `src/groundx/templates/_helpers/app/{extract,layout,ranker,summary,workspace}-api.tpl` — one per-service helper each, to expose the new keys from that service's `api` values block.
- `src/groundx/values.schema.json` — five `*.api` blocks (`extract.api`, `layout.api`, `ranker.api`, `summary.api`, `workspace.api`), each `additionalProperties: false`; new keys must be declared in all five.
- `src/groundx/values.yaml` — the five services' default blocks, adding the shipped defaults above.
- `helm/` — the manual, hand-synced mirror of the same template/schema/default files (no regen guard exists for this mirror; see this repo's `AGENTS.md`).
- `src/groundx/tests/` and `__snapshot__/{api,ranker,workspace}_test.yaml.snap` — golden-file updates from `helm unittest -u src/groundx`, committed as a separate hunk.

**Affected environments and rollout / rollback**: every environment that deploys this chart at `0.2.7` (or a later tag once this lands) picks up the new defaults on the next `helm upgrade`, whether or not that environment's own values file sets anything for these keys — the new keys are chart defaults, not opt-in flags. Concretely, per key:
- Readiness `failureThreshold: 3` reproduces Kubernetes' current implicit default exactly, so no environment's probe behavior changes on this axis.
- Liveness and readiness `timeoutSeconds: 3` (replacing the implicit 1-second Kubernetes default) is a real behavior change for every existing deployment: probes get a 3x larger response-time budget before being counted as failed. This can only make ejection/restart less likely, never more, because it strictly widens the passing window; there is no scenario in which raising a timeout newly fails a probe that was passing before.

No stateful or data resource is touched — this is probe-timing configuration only, with no PVC, database, or queue involved. Rollback is the chart's normal rollback path: a `helm rollback` to the prior release, or (without a full chart rollback) an explicit `timeoutSeconds`/`failureThreshold` override in the environment's own values file to restore the prior effective numbers.

**What this change does and does not fix**: this chart change ships configurable knobs with safe, more-forgiving defaults; it is not itself a behavioral fix to the FRA-145 production incident. The live values consumed by the production deployment are `groundx-helm-charts` `applications/prod/groundx/values.yaml`, a repo outside this workspace that nobody on this change can read or edit — merging this change does not move production's effective probe timing until someone edits that external repo (or a later chart-version bump propagates the new defaults, subject to that repo's own upgrade cadence). The actual incident root cause (blocking Redis I/O on the event loop starving the `/health` handler) is fixed entirely by the paired `ai-server` change in this same feature; this chart change only removes the artificially tight 1-second/implicit-3 ceiling so that fix, once its response lands within budget, is not undermined by an unrelated probe-timing default.

**Open design questions**: none — the shipped defaults, the two upgrade-behavior determinations, and the affected-file list are fully specified by the accepted plan; no `superpowers:brainstorming` session is needed.

**Dependencies**: none upstream. `ai-server` is the same-level producer of the `GET /health` endpoint this template's probes call; per the contract outline the touchpoint is additive (address, method, and 200-shape unchanged), so the two repos collapse to one dependency level and either may ship first.
