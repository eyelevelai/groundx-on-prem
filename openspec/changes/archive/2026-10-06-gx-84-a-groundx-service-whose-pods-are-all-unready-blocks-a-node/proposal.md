## Why

A PodDisruptionBudget the chart renders sets only `minAvailable: 1`, so Kubernetes applies its default `IfHealthyBudget` policy. When every pod of a service is running but not ready (a crash-looping or model-loading inference pod), the budget is never met and every eviction is refused, so `kubectl drain` waits until it times out even though another node is free. Setting `unhealthyPodEvictionPolicy: AlwaysAllow` lets those unready pods be evicted regardless of the budget. This follows GX-74, which added the opt-in budgets and deferred this field to GX-84.

## What Changes

- Add `unhealthyPodEvictionPolicy: AlwaysAllow` under `spec:`, directly after `minAvailable: 1`, in the PodDisruptionBudget block of each of five templates: `templates/app/api.yaml`, `celery.yaml`, `golang.yaml`, `inference.yaml`, `metrics.yaml`.
- Apply it in `src/groundx` first, then mirror the same edit byte-for-byte into `helm/templates/app/` (the gate's `verify_mirrors()` byte-compares the two trees).
- The field is rendered unconditionally whenever a budget renders. There is no new values setting and no `values.schema.json` change.
- Extend the existing helm-unittest suites with one assertion per template in `src/groundx/tests/api_pdb_test.yaml` (the celery enabled case renders two budgets, so `documentIndex` 1 and 3) and one assertion in `helm/tests/drain_protection_test.yaml`. No new cases, no new CI job, no snapshot regeneration (no snapshot contains a PodDisruptionBudget).
- Add a MODIFIED delta to `openspec/specs/api-availability/spec.md` so the budget requirement states the policy.
- Behavior change: budgets are off by default, so default renders of both chart copies are unchanged. With a budget enabled, a running but not-ready pod can now be evicted by a drain even when the service is below `minAvailable`. Healthy pods remain protected by `minAvailable: 1`. This is not a breaking change.

Out of scope: configurable `minAvailable`, a values knob for the policy, the replica-count warning, and enabling budgets by default.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `api-availability`: the opt-in PodDisruptionBudget requirement gains `unhealthyPodEvictionPolicy: AlwaysAllow` on every rendered budget, in both chart surfaces.

## Impact

- Files: five templates under `src/groundx/templates/app/` and their `helm/templates/app/` mirrors, two helm-unittest files, and `openspec/specs/api-availability/spec.md`. All lines are on branch `0.2.7` at `2f806fb`; the field is absent from `src` and `helm` there.
- Blast radius: only clusters that enable a service's `disruptionBudget.enabled` and then upgrade the chart. Disabled budgets render nothing, so no environment changes by default. No stateful resource is touched.
- Cluster versions: the field takes effect on Kubernetes 1.27+ (feature on by default) and GA in 1.31. Per the ticket, on 1.26 the API server drops it silently (a drain there still blocks) and on 1.25 `helm install` succeeds with an "unknown field" warning. Behavior on 1.21-1.24 is unverified.
- Rollback or roll-forward: revert the field in both chart copies and upgrade; a budget without the field returns to the default `IfHealthyBudget` policy. Nothing is deployed or drained by this change; validation is `helm template`, `helm lint` and `helm unittest` only.
- Open design questions: none. The 1.21-1.24 unknown is carried as an open question to the ticket owner and does not change the approach.
