## Context

The chart stores the layout inference runtime mode in `layout.inference.deviceType`. The helper defaults that field to `cuda`, and config templates pass it into the application config.

Container resources are rendered separately from `layout.inference.resources`. The default values include:

- `resources.limits.nvidia.com/gpu: 1`
- `resources.requests.nvidia.com/gpu: 1`

So a user can correctly set `deviceType: cpu` and still get a pod that asks Kubernetes for a GPU.

## Goals / Non-Goals

**Goals:**

- Make `deviceType: cpu` sufficient to stop `layout-inference` from requesting GPU resources.
- Preserve CPU and memory requests/limits.
- Keep non-CPU rendering unchanged.
- Keep node placement explicitly controlled by existing node, affinity, toleration, and node selector values.
- Cover the behavior with Helm rendering tests.

**Non-Goals:**

- Do not change runtime application behavior inside the layout image.
- Do not resize the default CPU or memory values.
- Do not move pods between node groups based on `deviceType`.
- Do not solve general cluster capacity, OpenShift SCC, Strimzi API-version, or node-taint issues.
- Do not change ranker or summary inference behavior unless follow-up testing shows they have the same CPU-mode contract.

## Decisions

Use render-time resource normalization for `layout-inference`.

When `include "groundx.layout.inference.deviceType" .` resolves to `cpu`, the chart should deep-copy `layout.inference.resources`, remove NVIDIA extended resource keys from `requests` and `limits`, then set the sanitized resources on the service settings map.

This is preferred over changing defaults because defaults still need GPU resources for normal non-CPU deployments. It is also preferred over documenting `nvidia.com/gpu: "0"` because users should not need to know Kubernetes extended-resource edge cases to select CPU mode.

Render omission is preferred over rendering `0`: a CPU pod should not include GPU extended resources at all.

`deviceType` is a device-resource mode, not a scheduling policy. The chart should not infer a CPU node, remove affinity, remove tolerations, or alter node selectors just because `deviceType: cpu` is set. Deployers already configure node placement explicitly.

This change should not add a schema enum for `deviceType`. It only gives `cpu` special resource-rendering behavior and leaves all other values on the existing path.

## Test Strategy

Add targeted Helm unittest assertions for the rendered `layout-inference` Deployment. Snapshot updates alone are not enough because `templates/app/inference.yaml` renders multiple inference Deployments.

The CPU-mode tests should use `documentSelector` with `metadata.name: layout-inference`, then assert:

- `spec.template.spec.containers[0].resources.requests["nvidia.com/gpu"]` does not exist;
- `spec.template.spec.containers[0].resources.limits["nvidia.com/gpu"]` does not exist;
- CPU and memory resources still exist where defaults or overrides provide them.

Add fixtures for both default CPU mode and the customer repro shape where `deviceType: cpu` is combined with a partial `layout.inference.resources` override. At minimum, cover a GPU limit set to `0` and a non-GPU limit override that omits the GPU key, because Helm map merging can otherwise retain default GPU requests or limits.

The OpenShift render check should also inspect the rendered `layout-inference` Deployment, not only confirm that Helm renders. It should fail if that Deployment contains `nvidia.com/gpu`.

## Risks / Trade-offs

- A CPU-mode deployment with intentionally supplied GPU keys will have those keys ignored for `layout-inference`. That is intentional because `deviceType: cpu` is the clearer source of truth.
- Helm map mutation can accidentally modify shared values. The implementation should use a deep copy before removing keys.
- A CPU-mode deployment still needs correct node placement values for the target cluster. This change only removes GPU resource requests/limits.

## Branch Scope

This is a chart source fix for the 0.2.7 branch.

The implementation should update `src/groundx` and sync the matching `helm/` mirror file because the production Helm gate checks mirror parity. Packaging, published chart replacement, and the release process are outside this plan.

No data migration is expected.

## Alternatives Considered

1. Document the current workaround: set both GPU request and limit to `0`.
   - Simple, but keeps the footgun and still makes CPU mode surprising.
2. Remove GPU defaults from chart values.
   - Breaks default non-CPU deployments.
3. Normalize resources when `deviceType: cpu`.
   - Best fit. CPU mode becomes self-contained while GPU defaults remain intact.
