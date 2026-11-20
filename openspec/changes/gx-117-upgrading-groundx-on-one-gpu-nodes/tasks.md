## 1. Default GPU rollout

- [ ] 1.1 Keep the strategy and deadline asserts in `src/groundx/tests/inference_test.yaml` and `src/groundx/tests/files/values.inference-gpu-rollout.yaml` as the failing tests for the template change (stubs authored in the tasks phase)
  check: t=$(mktemp -d) && cp -r src/groundx "$t/groundx" && (cd "$t/groundx" && helm unittest -f tests/inference_test.yaml .)
- [ ] 1.2 In `src/groundx/templates/app/inference.yaml` render `RollingUpdate` with `maxSurge: 0` and `progressDeadlineSeconds` = grace period + 600 when `updateStrategy` is empty and a rendered GPU quantity is above 0; copy the file byte for byte to `helm/templates/app/inference.yaml`
  check: d=$(helm template x src/groundx -f src/groundx/values.yaml --set search.password=a,search.privilegedPassword=b -s templates/app/inference.yaml) && test "$(echo "$d" | yq 'select(.metadata.name=="layout-inference") | .spec.progressDeadlineSeconds')" = 1500 && test "$(echo "$d" | yq 'select(.metadata.name=="layout-inference") | .spec.strategy.rollingUpdate.maxSurge')" = 0 && cmp -s src/groundx/templates/app/inference.yaml helm/templates/app/inference.yaml
- [ ] 1.3 Hand-patch the affected blocks of `inference_test.yaml.snap` (21 Deployments) and `ranker_test.yaml.snap` (1) with the new lines, no `-u`
  check: test "$(grep -c 'progressDeadlineSeconds:' src/groundx/tests/__snapshot__/inference_test.yaml.snap)" = 21 && test "$(grep -c 'progressDeadlineSeconds:' src/groundx/tests/__snapshot__/ranker_test.yaml.snap)" = 1 && t=$(mktemp -d) && cp -r src/groundx "$t/groundx" && (cd "$t/groundx" && helm unittest -f tests/inference_test.yaml -f tests/ranker_test.yaml .)

## 2. Upgrade guidance

- [ ] 2.1 Update `docs/upgrades.md`: new default, outage on each upgrade, opt-out `updateStrategy: RollingUpdate`, `kubectl rollout status` as the completion check; replace the stale sentence on line 216
  check: grep -q 'maxSurge' docs/upgrades.md && grep -q 'kubectl rollout status' docs/upgrades.md && ! grep -qF 'keep `updateStrategy: Recreate` unless a spare GPU is free' docs/upgrades.md

## 3. Gate

- [ ] 3.1 Run the push gate `.build/bin/validate-helm.sh`
  check: n/a — privileged gate script, run by the push gate and CI, not by a task check

See workspace `openspec/changes/gx-117-upgrading-groundx-on-one-gpu-nodes/tasks.md` for cross-service coordination and deferred items.
