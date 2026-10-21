## 1. Thin slice: layout-inference renders an init container and a direct supervisord command

- [x] 1.1 In `src/groundx/templates/_helpers/app/layout-inference.tpl`, set `execOpts` to `exec` and add `initCommand` (`python /app/init-layout.py`) in `groundx.layout.inference.settings`.
  check: helm unittest -f 'tests/inference_test.yaml' src/groundx
- [x] 1.2 In `src/groundx/templates/app/inference.yaml`, when `initCommand` is set append an `init-layout` init container after all other init containers (same image, pull policy, `workingDir`, `POD_NAME` + CA env, `envFrom` secrets, container security context, the same `groundx.renderContainerResources` resources as the main container; `config-models`, `config-volume`, CA and, when a PVC exists, `model-volume` mounts) whose command is `/bin/sh -c "export PYTHONPATH={{ $wd }}:$PYTHONPATH && exec <initCommand with $wd>"`. The main command keeps its shell form and, with `execOpts: exec`, no longer contains `init-layout.py`. No env `PYTHONPATH` is added. Services without `initCommand` render byte-identically.
  check: helm unittest -f 'tests/inference_test.yaml' src/groundx
- [x] 1.3 Retarget the layout-inference command assertion in `src/groundx/tests/inference_test.yaml`, add explicit asserts there (layout-inference default case: `init-layout` last, `exec python /app/init-layout.py`, GPU 1; cpu-mode case: no GPU on `init-layout`; one file-access CA and secret case), and hand-patch `src/groundx/tests/__snapshot__/inference_test.yaml.snap` so only `layout-inference` documents change; never run `helm unittest -u`. Review `git diff` of the snapshot to confirm ranker/summary/workspace/extract documents are untouched.
  check: helm unittest -f 'tests/inference_test.yaml' src/groundx
- [x] 1.4 Mirror `layout-inference.tpl` and `inference.yaml` byte-for-byte into `helm/templates/` and confirm the storage-contract mirror check passes.
  check: bash -c "helm unittest -f 'tests/inference_test.yaml' src/groundx && diff src/groundx/templates/_helpers/app/layout-inference.tpl helm/templates/_helpers/app/layout-inference.tpl && diff src/groundx/templates/app/inference.yaml helm/templates/app/inference.yaml"

## 2. Lifecycle proof: hand-run minikube test, recorded outside this repo

- [x] 2.1 Run the hand-run minikube lifecycle test (stand-in image with real supervisord and real Celery against the chart's unedited `supervisord.conf`, in-cluster Redis, consumption measured from the broker/result side) against the previous chart (red) and the fixed chart (green). The kit is kept outside this repo, in the engineering-context GX-115 change folder at `evidence/lifecycle/kit/`; nothing is added under `bin/tests/` or `src/containers/` in this repo.
  check: n/a — hand-run minikube test executed outside this repo (`kubectl delete pod` in a privileged repo context; not runnable by the pipeline)
- [x] 2.2 Record the runs: the red run on the previous chart (fails assertion (a)) and the green run on the fixed chart (passes) in the PR description and the engineering-context GX-115 change folder, together with the EKS round on `groundx-validation`.
  check: n/a — evidence recorded outside this repo

## 3. Gate

- [x] 3.1 Run the repo gate; it covers helm lint, the full helm unittest suite, snapshot stability and the helm/ mirror check.
  check: .build/bin/validate-helm.sh
- [x] 3.2 Validate the OpenSpec change (`openspec validate --type change gx-115-layout-inference-pods-keep-accepting-tasks-after-deletion`).
  check: n/a — non-behavioral artifact validation; it passes on unchanged code, so it cannot define a RED baseline

See workspace `openspec/changes/archive/2026-10-20-gx-115-layout-inference-pods-keep-accepting-tasks-after-deletion/tasks.md` for cross-service coordination and deferred items (the dev EKS round runs outside the pipeline).
