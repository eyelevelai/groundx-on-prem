# Tasks — GX-124: Default 900-second shutdown wait for the Go queue services

Checks run from the repo root with `bash -c`, using `helm` on `PATH` and the pinned helm-unittest plugin. No check uses `helm unittest -u` or prints a rendered manifest.

Unit-test checks run whole suite files (helm-unittest cannot select one case), and `golang_test.yaml` and `resources_test.yaml` include cases that read the Google-OCR credentials fixture the gate normally generates. Each such check therefore creates `src/groundx/files/ocr/gcv-test.json`, runs, and removes it again; it refuses nothing and leaves the tree as it found it.

`.build/bin/validate-helm.sh` is bash-only, needs the helm-unittest plugin pin check to pass and `yq`, and on this Windows machine stops at the plugin-version step (observed on the unchanged branch). Task 7 runs it in WSL. The other checks here (`helm template`, `helm unittest`, `verify-helm-snapshots.py`, `verify-storage-contract.py`) run on Windows.

Mirror rule: every template change under `src/groundx/` is copied byte-for-byte into `helm/` in the same group of work; `diff -r src/groundx/templates helm/templates` must be empty.

Commit plan: tests, helper edits and the `helm/` mirror in one commit; the hand-patched `__snapshot__` blocks (task 4) in a separate commit.

Rollout sequence (no manual operations, no secret changes): run the validation-EKS Kafka task (8.1) before merge; release the chart as 0.2.8, which restarts the Deployments named in `design.md` decision 4 once; merge the `groundx-studio-harness` documentation PR only after chart 0.2.8 is published.

## 1. Tests first (thin slice: the default and the override, end to end)

- [x] 1.1 Invert and add the unit cases (authored with this plan, in `src/groundx/tests/golang_test.yaml` and `src/groundx/tests/resources_test.yaml`): in `golang_test.yaml` the `summary-client` no-`gracePeriod` case asserts `terminationGracePeriodSeconds: 900`, a `process` override of 120 leaves `upload` at 900, and `groundx` and `layout-webhook` still render none (selected through `spec.selector.matchLabels.app`); in `resources_test.yaml` the no-`gracePeriod` case asserts `drainSeconds: 870` in all five blocks and the two isolation cases use a non-default override (600 on `summaryClient`, 120 on `preProcess`) with the other four blocks at 870. Fails today on the unchanged helpers; ticked together with 4.1, because the same suites hold snapshot cases
  check: mkdir -p src/groundx/files/ocr && printf '{\n  "type": "service_account",\n  "project_id": "groundx-helm-test",\n  "private_key_id": "test",\n  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",\n  "token_uri": "https://oauth2.googleapis.com/token"\n}\n' > src/groundx/files/ocr/gcv-test.json; helm unittest -f tests/golang_test.yaml -f tests/resources_test.yaml src/groundx; rc=$?; rm -f src/groundx/files/ocr/gcv-test.json; rmdir src/groundx/files/ocr src/groundx/files 2>/dev/null; exit $rc

## 2. Helper edits in `src/groundx`

- [x] 2.1 In each of `src/groundx/templates/_helpers/app/{pre-process,process,queue,summary-client,upload}.tpl`, after the `cooldown` default inside `groundx.<svc>.replicas`, add `if not (hasKey $in "gracePeriod")` then `set $in "gracePeriod" 900` (same shape as the neighbouring defaults, no comment); leave `golang.yaml`, `config-yaml.yaml`, `values.yaml` and `values.schema.json` unchanged. With nothing set, `golang.yaml` renders 900 on exactly five Deployments and the config renders `drainSeconds: 870` five times; a `process` override of 120 renders 120 and `drainSeconds: 90` for `process` only and leaves four blocks at 870
  check: [ "$(helm template t src/groundx --show-only templates/app/golang.yaml | grep -c 'terminationGracePeriodSeconds: 900')" -eq 5 ] && [ "$(helm template t src/groundx --show-only templates/resources/config-yaml.yaml | grep -c 'drainSeconds: 870')" -eq 5 ] && [ "$(helm template t src/groundx --set process.replicas.gracePeriod=120 --show-only templates/app/golang.yaml | grep -c 'terminationGracePeriodSeconds: 120')" -eq 1 ] && c=$(helm template t src/groundx --set process.replicas.gracePeriod=120 --show-only templates/resources/config-yaml.yaml) && [ "$(printf '%s\n' "$c" | grep -c 'drainSeconds: 90')" -eq 1 ] && [ "$(printf '%s\n' "$c" | grep -c 'drainSeconds: 870')" -eq 4 ]

## 3. The `helm/` mirror

- [x] 3.1 Copy the five edited helper files byte-for-byte into `helm/templates/_helpers/app/`; render the published-chart copy with nothing set and confirm the same five defaults, with the template trees identical and the storage-contract verifier (which byte-compares `templates/`) passing
  check: [ "$(helm template t helm --show-only templates/app/golang.yaml | grep -c 'terminationGracePeriodSeconds: 900')" -eq 5 ] && [ "$(helm template t helm --show-only templates/resources/config-yaml.yaml | grep -c 'drainSeconds: 870')" -eq 5 ] && diff -r src/groundx/templates helm/templates && "$(command -v python3 || command -v python)" -I .build/bin/verify-storage-contract.py

## 4. Snapshots (separate commit)

- [x] 4.1 Hand-patch the affected `src/groundx/tests/__snapshot__/*.snap` blocks in `golang_test.yaml.snap`, `resources_test.yaml.snap` and `metrics_test.yaml.snap` from the diff a plain `helm unittest` prints, never with `-u`, in a commit separate from groups 1 to 3: `config-hash` on the golang Deployments, `terminationGracePeriodSeconds: 900` on the five services, `drainSeconds: 870` in the five config blocks and in the embedded schema-migration Secret config. Every other `.snap` file stays byte-identical (`git diff --stat` shows only these three). Then the three suites pass with no snapshot written and the snapshot label verifier passes
  check: mkdir -p src/groundx/files/ocr && printf '{\n  "type": "service_account",\n  "project_id": "groundx-helm-test",\n  "private_key_id": "test",\n  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",\n  "token_uri": "https://oauth2.googleapis.com/token"\n}\n' > src/groundx/files/ocr/gcv-test.json; helm unittest -f tests/golang_test.yaml -f tests/resources_test.yaml -f tests/metrics_test.yaml src/groundx && "$(command -v python3 || command -v python)" -I .build/bin/verify-helm-snapshots.py; rc=$?; rm -f src/groundx/files/ocr/gcv-test.json; rmdir src/groundx/files/ocr src/groundx/files 2>/dev/null; exit $rc

## 5. Spec delta

- [x] 5.1 Keep `openspec/changes/gx-124-deploys-and-scale-downs-cancel-running-document-jobs-because/specs/queue-service-grace-period/spec.md` as the change delta for `openspec/specs/queue-service-grace-period/spec.md` (rename and modify the "No gracePeriod set" requirement, modify the drainSeconds and sweep-consistency requirements, keep per-service override isolation); do not edit the capability spec directly
  check: n/a — OpenSpec delta authored with the plan; `openspec validate --type change` runs in task 6.1 and at verify

## 6. Full local gate

- [x] 6.1 Run everything the gate runs that works on this machine: the full `helm unittest` suite with the OCR fixture, `helm lint` for both chart surfaces, the snapshot label verifier, the storage-contract and mirror verifier, `diff -r src/groundx/templates helm/templates`, `openspec validate --type change`, and `git diff --check`
  check: mkdir -p src/groundx/files/ocr && printf '{\n  "type": "service_account",\n  "project_id": "groundx-helm-test",\n  "private_key_id": "test",\n  "client_email": "test@groundx-helm-test.iam.gserviceaccount.com",\n  "token_uri": "https://oauth2.googleapis.com/token"\n}\n' > src/groundx/files/ocr/gcv-test.json; helm unittest src/groundx && helm lint src/groundx && helm lint helm && "$(command -v python3 || command -v python)" -I .build/bin/verify-helm-snapshots.py && "$(command -v python3 || command -v python)" -I .build/bin/verify-storage-contract.py && diff -r src/groundx/templates helm/templates && openspec validate --type change gx-124-deploys-and-scale-downs-cancel-running-document-jobs-because && git diff --check; rc=$?; rm -f src/groundx/files/ocr/gcv-test.json; rmdir src/groundx/files/ocr src/groundx/files 2>/dev/null; exit $rc

## 7. Gate in WSL

- [ ] 7.1 (open: needs WSL Ubuntu, a human runs it) Run `bash .build/bin/validate-helm.sh` in WSL Ubuntu from a clone or worktree of this branch (helm-unittest plugin at the pinned version, `yq` v4 installed) and record the result in the PR body
  check: n/a — validate-helm.sh stops at its plugin-version step on this Windows machine, so a human runs it in WSL; the runnable parts are covered by task 6.1

## 8. Hand-off

- [x] 8.1 (done 2026-10-23: results in the PR body and in the engineering-context record evidence/kafka-validation.md; the duplicate it found is tracked as GX-138) Pre-merge validation on the validation EKS (never production): roll one of the five services with drain on while a long job is in flight, capture before (the current chart) and after (this branch) with the same method, and record whether the draining pod keeps its Kafka partition, whether any message is processed by two pods at once, and whether a partition stalls. If concurrent duplicates or stalls are confirmed, the ticket author decides before merge whether the services' redelivery checks are safe under concurrency
  check: n/a — run on validation EKS by a human before merge
- [ ] 8.2 (open: PR body is written by the orchestrator after the gate) Write the release notes in the PR body: upgrading restarts the Deployments listed in `design.md` decision 4 once (with the render command that derives the list), the busy-pod rollout time of up to 900 seconds, the autoscaler `--max-graceful-termination-sec` cap (documented default 600, document only), SQS installs gaining drain-time lease release (decision 8), the rollback (redeploy the previous chart; services return to the 30-second default unless `gracePeriod` is set), one line saying the default sits in the replicas helpers rather than an `else` branch in `golang.yaml`/`config-yaml.yaml` with identical rendered output, which snapshot blocks changed and why, and a paragraph a human pastes into the 0.2.8 GitHub Release at release cut; add no new file
  check: n/a — PR text, written after the gate passes

See workspace `openspec/changes/gx-124-deploys-and-scale-downs-cancel-running-document-jobs-because/tasks.md` for cross-service coordination and deferred items (the `groundx-studio-harness` documentation PR, held until chart 0.2.8 is published).
