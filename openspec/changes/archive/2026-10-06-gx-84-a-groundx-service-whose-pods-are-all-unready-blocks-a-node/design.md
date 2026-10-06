## Goals / Non-Goals

**Goals:**

- Every PodDisruptionBudget the chart renders carries `unhealthyPodEvictionPolicy: AlwaysAllow`, in `src/groundx` and the `helm/` mirror, so a drain can evict running but not-ready pods. Motivation and cluster-version behavior are in `proposal.md`.

**Non-Goals:**

- A values setting for the policy, a configurable `minAvailable`, the replica-count warning, and enabling budgets by default (see the proposal's out-of-scope list).

## Decisions

### Render the field unconditionally inside each existing budget block

The field is added as a literal line under `spec:` directly after `minAvailable: 1`, in the five existing budget blocks (`api.yaml`, `celery.yaml`, `golang.yaml`, `inference.yaml`, `metrics.yaml`). The blocks are already gated by each service's `disruptionBudget.enabled`, so a disabled budget renders nothing and default renders and snapshots are untouched.

Alternatives rejected:

- A values knob (`disruptionBudget.unhealthyPodEvictionPolicy`): needs a `values.schema.json` change on a strict `additionalProperties: false` contract and per-service plumbing, for a setting the ticket says has one correct value.
- A shared helper that emits the budget spec: a one-line addition to five existing blocks does not justify a new abstraction, and a helper would change the already-shipped budget structure for no behavior gain.
- Gating the field on the cluster's Kubernetes version (`.Capabilities.KubeVersion`): unnecessary, because the ticket reports that on 1.26 the API server drops the field silently and on 1.25 `helm install` succeeds with an "unknown field" warning (recorded in the proposal).

### Edit `src/groundx` first, then mirror byte-for-byte into `helm/`

`src/groundx` is the source of truth and `helm/` is a manual mirror with no regen script. The mirror edit is the same line at the same position in the same five files; the gate's `verify_mirrors()` byte-compares the two `templates/` trees, so a mismatch fails `.build/bin/validate-helm.sh`. Mirror coverage therefore comes from that comparison; `helm/tests/drain_protection_test.yaml` adds one rendered assertion on the published chart.

### Extend existing helm-unittest cases rather than add new ones

One assertion per template is added to cases that already render each budget: `api_pdb_test.yaml` gets one each for the api, golang, metrics and inference templates and two for celery (the enabled case renders `layout-map` and `layout-ocr` budgets at `documentIndex` 1 and 3 among four documents). `drain_protection_test.yaml` gets one on the metrics budget. No snapshot contains a PodDisruptionBudget, so no snapshot changes and `helm unittest -u` is never used.

### Rollout and blast radius

Only clusters that set a service's `disruptionBudget.enabled: true` and then upgrade the chart see a difference: running but not-ready pods become evictable regardless of the budget, while healthy pods stay protected by `minAvailable: 1`. Rollback is removing the line in both chart copies and upgrading. Nothing is deployed or drained by this change; validation is `helm template`, `helm lint` and `helm unittest` only. There is no stateful resource, migration or ordering concern.

## Risks / Trade-offs

- [Mirror drift between `src/groundx` and `helm/`] -> the same edit is applied to both trees and `verify_mirrors()` in `validate-helm.sh` fails on any byte difference.
- [Behavior on Kubernetes 1.21-1.24 is unverified] -> carried as a question to the ticket owner in the proposal; the ticket's recorded tests cover 1.25, 1.26 and 1.34 and the field is additive.
- [Unready pods are evictable even when the service has no healthy replica] -> intended: it is the behavior the ticket asks for, and it only applies where an operator already opted into a budget.
