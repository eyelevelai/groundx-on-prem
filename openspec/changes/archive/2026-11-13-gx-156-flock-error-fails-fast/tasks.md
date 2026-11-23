## 1. Lock loop

- [x] 1.1 In `src/groundx/templates/app/inference.yaml` replace `until flock -n 9; do` with `until err=$(flock -n 9 2>&1); do` and, first in the loop body, exit 1 with `Cannot lock $lock: $err. The model volume must support file locks.` when `err` is non-empty; copy the file byte-for-byte to `helm/templates/app/inference.yaml`
  check: grep -qF 'until err=$(flock -n 9 2>&1); do' src/groundx/templates/app/inference.yaml && grep -qF 'The model volume must support file locks."' src/groundx/templates/app/inference.yaml && ! grep -qF 'until flock -n 9; do' src/groundx/templates/app/inference.yaml && cmp -s src/groundx/templates/app/inference.yaml helm/templates/app/inference.yaml
- [x] 1.2 Hand-patch `src/groundx/tests/__snapshot__/inference_test.yaml.snap` (31 copies) and `ranker_test.yaml.snap` (1 copy) to the new loop, no `-u`
  check: test "$(grep -cF 'until err=$(flock -n 9 2>&1); do' src/groundx/tests/__snapshot__/inference_test.yaml.snap)" = 31 && test "$(grep -cF 'until err=$(flock -n 9 2>&1); do' src/groundx/tests/__snapshot__/ranker_test.yaml.snap)" = 1 && t=$(mktemp -d) && cp -r src/groundx "$t/groundx" && (cd "$t/groundx" && helm unittest -f tests/inference_test.yaml -f tests/ranker_test.yaml .)
- [ ] 1.3 Run the full gate `.build/bin/validate-helm.sh`
  check: n/a — privileged gate script, run by the push gate and CI, not by a task check
