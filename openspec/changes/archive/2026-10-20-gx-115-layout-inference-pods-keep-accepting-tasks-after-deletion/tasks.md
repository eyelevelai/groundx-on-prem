## 1. Thin slice: layout-inference renders an init container and a direct supervisord command

- [x] 1.1 In `src/groundx/templates/_helpers/app/layout-inference.tpl`, set `execOpts` to `exec` and add `initCommand` (`python /app/init-layout.py`) in `groundx.layout.inference.settings`.
  check: helm unittest -f 'tests/layout_inference_init_test.yaml' src/groundx
- [x] 1.2 In `src/groundx/templates/app/inference.yaml`, when `initCommand` is set append an `init-layout` init container after all other init containers (same image, pull policy, `workingDir`, `POD_NAME` + CA env, `envFrom` secrets, container security context, the same `groundx.renderContainerResources` resources as the main container; `config-models`, `config-volume`, CA and, when a PVC exists, `model-volume` mounts) whose command is `/bin/sh -c "export PYTHONPATH={{ $wd }}:$PYTHONPATH && exec <initCommand with $wd>"`. The main command keeps its shell form and, with `execOpts: exec`, no longer contains `init-layout.py`. No env `PYTHONPATH` is added. Services without `initCommand` render byte-identically.
  check: helm unittest -f 'tests/layout_inference_init_test.yaml' src/groundx
- [x] 1.3 Retarget the layout-inference command assertion in `src/groundx/tests/inference_test.yaml` and hand-patch `src/groundx/tests/__snapshot__/inference_test.yaml.snap` so only `layout-inference` documents change; never run `helm unittest -u`. Review `git diff` of the snapshot to confirm ranker/summary/workspace/extract documents are untouched.
  check: helm unittest -f 'tests/inference_test.yaml' src/groundx
- [x] 1.4 Mirror `layout-inference.tpl` and `inference.yaml` byte-for-byte into `helm/templates/` and confirm the storage-contract mirror check passes.
  check: bash -c "helm unittest -f 'tests/layout_inference_init_test.yaml' src/groundx && diff src/groundx/templates/_helpers/app/layout-inference.tpl helm/templates/_helpers/app/layout-inference.tpl && diff src/groundx/templates/app/inference.yaml helm/templates/app/inference.yaml"

## 2. Lifecycle proof: hand-run minikube script and stand-in image

- [x] 2.1 Add `bin/tests/layout-inference-lifecycle/Dockerfile.layout-inference-stub` and its stand-ins: pip `supervisor`, real `celery` + `redis`, `init-layout.py` (configurable sleep, exits 0) and a minimal `document/celery_process.py` Celery app (one dummy task, in-cluster Redis broker). The chart's `supervisord.conf` is used unedited. Not under `src/containers/`; built only into minikube's docker; never pushed.
  check: n/a — hand-run test fixture; built and exercised only by the human-run lifecycle script in 2.2
- [x] 2.2 Add `bin/tests/layout-inference-lifecycle/run.sh`: builds the stand-in into minikube's docker, deploys an in-cluster Redis, renders `inference.yaml` + `layout-supervisord-conf` through `helm template` changed only via `--set` values (image, `layout.inference.deviceType=cpu`, dependency endpoints, storage class), applies it, keeps enqueuing tasks during the test, and measures consumption from the broker/result side. Asserts (a) pod deleted during init: zero tasks consumed by that pod; (b) pod deleted after start: in-flight task completes and the worker exits warm within the grace period. Exit non-zero on any violated assertion. Not wired into pre-push or CI.
  check: n/a — human-run minikube lifecycle test (executes repo files and `kubectl delete pod` in a privileged repo; not runnable by the pipeline)
- [x] 2.3 Record the human run: the script's output against the unchanged chart (expected fail on assertion (a)) and against the fixed chart (expected pass) in the PR body.
  check: n/a — human-run evidence recorded outside the repo

## 3. Gate

- [x] 3.1 Run the repo gate; it covers helm lint, the full helm unittest suite, snapshot stability and the helm/ mirror check.
  check: .build/bin/validate-helm.sh
- [x] 3.2 Validate the OpenSpec change (`openspec validate --type change gx-115-layout-inference-pods-keep-accepting-tasks-after-deletion`).
  check: n/a — non-behavioral artifact validation; it passes on unchanged code, so it cannot define a RED baseline

See workspace `openspec/changes/gx-115-layout-inference-pods-keep-accepting-tasks-after-deletion/tasks.md` for cross-service coordination and deferred items (the dev EKS round runs outside the pipeline).
