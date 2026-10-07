## Why

An opt-in budget with only `minAvailable: 1` blocks eviction when every selected pod is running but unready. `unhealthyPodEvictionPolicy: AlwaysAllow` permits those pods to move while protecting healthy pods. Kubernetes versions before 1.26 do not expose this field in their API schema, so normal Helm install validation can reject an enabled budget.

## What Changes

Render `unhealthyPodEvictionPolicy: AlwaysAllow` only when Helm reports Kubernetes 1.26 or newer, in the five existing budget templates. Edit `src/groundx` first, then copy the same files into the `helm/` mirror. Older clusters retain `minAvailable: 1` and the existing service selector without the unsupported field. No values setting or schema change is added.

Budget tests select a modern Kubernetes version and cover omission on 1.21 and 1.25 plus retention on 1.26. Default budgets remain disabled and snapshots are unchanged. The API availability specification and Harness deployment guidance use the same version rule.

## Capabilities

- Modified: `api-availability`, version-dependent unhealthy-pod eviction policy.
- New: none.

## Impact

Only enabled budgets change. Kubernetes before 1.26 keeps its previous drain behavior. Kubernetes 1.26 needs the alpha feature gate; 1.27 and later enable the policy by default. Development, staging and production receive this through their next chart upgrade. No application image, replica count, stateful resource, credential or extraction contract changes. Arcadia legacy, Arcadia v1, generic v1 and ADP v1 are unaffected because no extraction logic, prompt, schema or returned data changes.

Validation covers both chart copies, version boundaries, normal Helm install checking on an isolated Kubernetes 1.21 cluster, the full chart gate and minikube rendering. Nothing is deployed to customer or hosted clusters. Rollback is reverting the guard in both chart copies, which restores the old-cluster install rejection.

Open design questions: none.
