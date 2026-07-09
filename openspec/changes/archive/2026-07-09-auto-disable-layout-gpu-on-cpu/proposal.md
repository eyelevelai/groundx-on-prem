## Why

`layout-inference` can be configured with `layout.inference.deviceType: cpu`, but the chart still renders the default GPU resources from `layout.inference.resources`.

That means a CPU layout deployment can still request `nvidia.com/gpu: 1` and remain Pending on CPU-only OpenShift clusters. Setting only the GPU limit to `0`, omitting the GPU key in an override, or relying on `deviceType: cpu` is not enough because the chart defaults still supply the GPU request/limit.

## What Changes

When `layout.inference.deviceType` is `cpu`, the chart will render `layout-inference` container resources without NVIDIA GPU extended resource keys.

The change should:

- preserve non-GPU resource settings such as CPU and memory;
- remove GPU keys from both `resources.requests` and `resources.limits`;
- make the CPU intent win even if a values file also includes GPU keys;
- make the CPU intent win when Helm merges a partial resource override with the chart defaults;
- keep non-CPU behavior unchanged when `deviceType` is unset or not `cpu`;
- leave node placement, affinity, tolerations, and node selectors under explicit values control;
- update targeted Helm tests and OpenShift render validation so the CPU rendering path fails if GPU resources reappear.

The preferred rendered behavior is to omit the GPU keys, not render them as `0`.

## Capabilities

### New Capabilities

- `layout-inference-cpu-resources`: defines how the Helm chart renders `layout-inference` resources when CPU device mode is selected.

### Modified Capabilities

- None.

## Impact

- Affected chart source:
  - `src/groundx/templates/_helpers/app/layout-inference.tpl`
  - `helm/templates/_helpers/app/layout-inference.tpl`
  - possibly `src/groundx/templates/_helpers/elements/containerresources.tpl` if a reusable helper is cleaner
  - `src/groundx/tests/inference_test.yaml`
  - `src/groundx/tests/files/values.layout-inference.cpu*.yaml`
  - `src/groundx/tests/__snapshot__/inference_test.yaml.snap`
- Schema impact:
  - no schema change expected
- Blast radius:
  - limited to rendered `layout-inference` Deployment resources
  - CPU mode stops requesting GPU resources
  - CPU mode does not change configured node placement
  - non-CPU mode should render exactly as before
- Environments:
  - affects any Helm install or upgrade using `layout.inference.deviceType: cpu`
  - no data or stateful resource migration
- Branch scope:
  - fix in the 0.2.7 branch only
  - sync the `helm/` mirror file required by the production Helm gate
  - do not include chart release, packaging, or published chart replacement work in this plan
- Rollback:
  - revert the chart/template change, or set explicit GPU resources when running GPU mode
- Open design questions:
  - none
