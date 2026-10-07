## 1. Chart Behavior

- [x] 1.1 Add a layout inference resource normalization path in `src/groundx` that removes NVIDIA GPU resource keys when `layout.inference.deviceType: cpu`.
- [x] 1.2 Preserve existing CPU and memory resource values when GPU keys are removed.
- [x] 1.3 Keep non-CPU rendering unchanged.
- [x] 1.4 Do not change node, affinity, toleration, or node selector rendering based on `deviceType`.
- [x] 1.5 Sync the matching `helm/` mirror helper required by the production Helm gate, without packaging or publishing a chart release.

## 2. Tests

- [x] 2.1 Add Helm unittest fixture coverage for `layout.inference.deviceType: cpu` with default chart resources.
- [x] 2.2 Add Helm unittest fixture coverage for the customer repro shape: `layout.inference.deviceType: cpu` plus a partial `layout.inference.resources` override, including `nvidia.com/gpu: 0` under `layout.inference.resources.limits`.
- [x] 2.3 Add Helm unittest fixture coverage for `layout.inference.deviceType: cpu` plus a non-GPU resource override that omits the GPU key.
- [x] 2.4 Target the rendered `layout-inference` Deployment by document selector, not by snapshot position or a generic multi-document assertion.
- [x] 2.5 Assert that the selected `layout-inference` container does not contain `nvidia.com/gpu` in `resources.requests` or `resources.limits` for CPU mode.
- [x] 2.6 Assert that the selected `layout-inference` container keeps CPU and memory resources for CPU mode.
- [x] 2.7 Assert that CPU mode does not change rendered node placement fields.
- [x] 2.8 Assert that the default non-CPU rendering still includes `nvidia.com/gpu: 1`.
- [x] 2.9 Regenerate snapshots with `helm unittest -u src/groundx` after targeted assertions pass.

## 3. Validation

- [x] 3.1 Run `helm unittest src/groundx`.
- [x] 3.2 Run `helm template src/groundx -f src/groundx/values/minikube/values.yaml`.
- [x] 3.3 Run an OpenShift render check using `src/groundx/values/openshift/values.yaml` plus `layout.inference.deviceType=cpu`.
- [x] 3.4 In that OpenShift render output, inspect the `layout-inference` Deployment and fail validation if `nvidia.com/gpu` appears in the selected Deployment.
- [x] 3.5 Run `helm lint src/groundx`.
- [x] 3.6 Run `npx --yes @fission-ai/openspec@latest validate auto-disable-layout-gpu-on-cpu --strict`.
- [x] 3.7 Run `.build/bin/validate-helm.sh`.
