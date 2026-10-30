## 1. Thin slice: the fixed script renders from both charts and passes the guard

- [x] 1.1 Replace the `download-model` script in `src/groundx/templates/app/inference.yaml` with the flock version in `design.md` (Reference script), and copy it byte-for-byte into `helm/templates/app/inference.yaml`
  check: PATH="$HOME/go/bin:$PATH" bash src/groundx/tests/files/verify-download-model-lock.sh
- [x] 1.2 Hand-patch `src/groundx/tests/__snapshot__/inference_test.yaml.snap` (31 copies) and `ranker_test.yaml.snap` (1 copy) to the new rendered script, no `-u`
  check: test "$(grep -c 'exec 9>>' src/groundx/tests/__snapshot__/inference_test.yaml.snap)" = 31 && test "$(grep -c 'exec 9>>' src/groundx/tests/__snapshot__/ranker_test.yaml.snap)" = 1 && t=$(mktemp -d) && cp -r src/groundx "$t/groundx" && (cd "$t/groundx" && helm unittest -f tests/inference_test.yaml -f tests/ranker_test.yaml .)

## 2. Gate wiring and docs

- [x] 2.1 Add the guard step to `.build/bin/validate-helm.sh` after the probe-mirror step, announced as `==> Verifying download-model flock lock and failed-download handling (see GX-125)`, and add it to the usage list
  check: grep -qF '==> Verifying download-model flock lock and failed-download handling (see GX-125)' .build/bin/validate-helm.sh && grep -q 'bash src/groundx/tests/files/verify-download-model-lock.sh' .build/bin/validate-helm.sh
- [x] 2.2 Add `#### Upgrading Inference Services and the Model Download Lock` to the root `README.md` before `### Persistent Storage`: upgrade and rollback scale-to-0, `Init:Error` / `CrashLoopBackOff` and air-gapped seeding, missing or rejected flock and its remedy (no bypass value), cross-node locking verified on EFS only, no chart version
  check: s=$(sed -n '/^#### Upgrading Inference Services and the Model Download Lock/,/^### Persistent Storage/p' README.md); test -n "$s" && for k in 'scale' 'rolling back' 'Init:Error' 'CrashLoopBackOff' 'air-gapped' 'seed' 'flock' 'EFS'; do printf '%s' "$s" | grep -q -- "$k" || exit 1; done
- [x] 2.3 List Docker and the chart busybox image as a `validate-helm.sh` prerequisite beside `yq` in `AGENTS.md` "How to run and test"
  check: grep -q 'verify-download-model-lock.sh' AGENTS.md
- [ ] 2.4 Run the full gate `.build/bin/validate-helm.sh` (lint, unittest on both surfaces, `verify-helm-snapshots.py`, `verify-storage-contract.py` mirror check, the new guard)
  check: n/a — privileged gate script, run by the push gate and CI, not by a task check

See workspace `openspec/changes/gx-125-interrupted-model-download-hangs-every-later-inference-pod/tasks.md` for cross-service coordination and deferred items (the engineering-context push-gate change, the before-merge busybox-fips flock confirmation, the harness docs follow-up ticket).
