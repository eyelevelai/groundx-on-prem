## 1. Default GPU rollout

- [x] 1.1 Keep the strategy and deadline asserts in `src/groundx/tests/inference_test.yaml` and `src/groundx/tests/files/values.inference-gpu-rollout.yaml` as the failing tests for the template change (stubs authored in the tasks phase)
  check: t=$(mktemp -d) && cp -r src/groundx "$t/groundx" && (cd "$t/groundx" && helm unittest -f tests/inference_test.yaml .)
- [x] 1.2 In `src/groundx/templates/app/inference.yaml` render `RollingUpdate` with `maxSurge: 0` and `progressDeadlineSeconds` = grace period + 600 when `updateStrategy` is empty and a rendered GPU quantity is above 0; copy the file byte for byte to `helm/templates/app/inference.yaml`
  check: d=$(helm template x src/groundx -f src/groundx/values.yaml --set search.password=a,search.privilegedPassword=b -s templates/app/inference.yaml) && test "$(echo "$d" | yq 'select(.metadata.name=="layout-inference") | .spec.progressDeadlineSeconds')" = 1500 && test "$(echo "$d" | yq 'select(.metadata.name=="layout-inference") | .spec.strategy.rollingUpdate.maxSurge')" = 0 && cmp -s src/groundx/templates/app/inference.yaml helm/templates/app/inference.yaml
- [x] 1.3 Hand-patch the affected blocks of `inference_test.yaml.snap` (21 Deployments) and `ranker_test.yaml.snap` (1) with the new lines, no `-u`
  check: test "$(grep -c 'progressDeadlineSeconds:' src/groundx/tests/__snapshot__/inference_test.yaml.snap)" -ge 21 && test "$(grep -c 'progressDeadlineSeconds:' src/groundx/tests/__snapshot__/ranker_test.yaml.snap)" = 1 && t=$(mktemp -d) && cp -r src/groundx "$t/groundx" && (cd "$t/groundx" && helm unittest -f tests/inference_test.yaml -f tests/ranker_test.yaml .)

## 2. Upgrade guidance

- [x] 2.1 Update `docs/upgrades.md`: new default, outage on each upgrade, opt-out `updateStrategy: RollingUpdate`, `kubectl rollout status` as the completion check; replace the stale sentence on line 216
  check: grep -q 'maxSurge' docs/upgrades.md && grep -q 'kubectl rollout status' docs/upgrades.md && ! grep -qF 'keep `updateStrategy: Recreate` unless a spare GPU is free' docs/upgrades.md

## 3. Summary on a GPU without a GPU request (amendment 2026-11-24)

- [x] 3.1 In `src/groundx/templates/app/inference.yaml` render `Recreate` with `progressDeadlineSeconds` = grace period + 600 when `updateStrategy` is empty, the pod runs on a GPU (`deviceType` is not `cpu`) and asks for no `nvidia.com/gpu`; copy the file byte for byte to `helm/templates/app/inference.yaml`
  check: d=$(helm template x src/groundx -f src/groundx/values.yaml --set search.password=a,search.privilegedPassword=b -s templates/app/inference.yaml) && test "$(echo "$d" | yq 'select(.metadata.name=="summary-inference") | .spec.strategy.type')" = Recreate && test "$(echo "$d" | yq 'select(.metadata.name=="summary-inference") | .spec.progressDeadlineSeconds')" = 900 && diff -q src/groundx/templates/app/inference.yaml helm/templates/app/inference.yaml
- [x] 3.2 Hand-patch the 8 `summary-inference` blocks of `inference_test.yaml.snap`, change the summary asserts in the grace period case to `Recreate` and 750, and set `ranker.inference.deviceType: cpu` in `values.inference-gpu-rollout.yaml`, no `-u`
  check: t=$(mktemp -d) && cp -r src/groundx "$t/groundx" && (cd "$t/groundx" && helm unittest -f tests/inference_test.yaml .)
- [x] 3.3 Update `docs/upgrades.md` and the `inference-gpu-rollout-strategy` spec for the summary default
  check: grep -q 'renders `Recreate`' docs/upgrades.md && grep -q 'A GPU pod that does not ask for a GPU is recreated' openspec/specs/inference-gpu-rollout-strategy/spec.md

## 4. Gate

- [ ] 4.1 Run the push gate `.build/bin/validate-helm.sh`
  check: n/a — privileged gate script, run by the push gate and CI, not by a task check

See workspace `openspec/changes/gx-117-upgrading-groundx-on-one-gpu-nodes/tasks.md` for cross-service coordination and deferred items.
