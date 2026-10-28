## Why

A layout-inference pod deleted while its image is loading or its models are initializing still starts Celery and keeps accepting page jobs until Kubernetes force-kills it (GX-115). The chart starts the container with `python /app/init-layout.py && exec supervisord`; the shell waits on `init-layout.py`, the shutdown signal arrives during that wait and is lost, and `supervisord` starts afterwards inside an already-terminating pod. GX-66 added `exec supervisord`, which only takes effect after `init-layout.py` completes, so it does not cover this window. In the 2026-10-15 FX load test on `groundx-prod-eks`, five pods deleted this way accepted more than 5,500 tasks after deletion began, while a pod deleted after startup shut down cleanly. Authority: the current Linear body for GX-115.

## What Changes

- In the layout-inference pod, run `python /app/init-layout.py` in a new init container (same image, working directory, `PYTHONPATH`, secret `envFrom`, config-models/config-volume/model-volume mounts, security context and CA env/mount as the main container), and start `supervisord` directly as PID 1 in the main container with no shell or init step in front of it. Applied in `src/groundx` and mirrored byte-for-byte into `helm/`.
- The ranker, summary, workspace and extract inference renders stay byte-identical to today.
- Update the `helm unittest` suite in the existing `src/groundx/tests/inference_test.yaml`: retarget the layout-inference command assertions, add init-container and direct-`supervisord` assertions, and hand-patch the affected snapshots (never `-u`).
- Prove the lifecycle with a hand-run minikube test whose results are recorded, not a committed script: the kit (script and stand-in image) is kept outside this repo in the engineering-context GX-115 change folder (`evidence/lifecycle/kit/`), and the red (previous chart) and green (fixed chart) runs are recorded in the PR description and that change folder. It applies the chart's `helm template` output, changed only through Helm values, and covers both timings: delete during init means Celery never starts and zero tasks are consumed; delete after start means warm shutdown.
- Accepted behavior (decision A): the init container gets no signal wrapper, so a pod deleted mid-init may stay Terminating until `init-layout.py` finishes or the grace period expires; it takes no tasks, so only scale-down is slower.
- Accepted residual risk: a pod deletion landing between init-container exit and `supervisord` installing its SIGTERM handler (sub-second) can still lose the signal, so that pod takes jobs until the grace-period SIGKILL. The same window exists for the five layout Celery workers. Accepted as a small risk at the plan gate. `shareProcessNamespace` was considered and rejected: killing `init-layout.py` mid-write would leave a truncated model file on the shared ReadWriteMany model cache, blocking every later layout pod.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `layout-worker-graceful-shutdown`: the requirement "Layout workers receive SIGTERM through exec supervisord" changes for layout-inference (init container plus `supervisord` as PID 1 instead of `init-layout.py && exec supervisord`); the layout Celery-worker `exec` commands and the "other workloads keep their startup command" scenario carry over. "Existing values files keep validating and rendering" is amended to permit the layout-inference init container and command as the only render diff.

## Impact

- Code: `src/groundx/templates/_helpers/app/layout-inference.tpl`, `src/groundx/templates/app/inference.yaml`, their `helm/` mirrors, and `src/groundx/tests/inference_test.yaml` with its snapshots. No lifecycle script or stand-in image is added to this repo.
- Blast radius: any environment running a chart with layout inference enabled; a chart upgrade restarts the layout-inference Deployment once. No data or stateful resource is touched, and no values schema or API changes. The layout-inference image is used unchanged.
- Rollback: roll back the chart release, which restores the previous startup command. Roll-forward carries no migration.
- Pipeline limits: it never deploys. A human-run dev EKS round (including the "deleted while the image is still downloading" timing) follows outside the pipeline.
- Out of scope: stuck-document monitoring or recovery, Celery/Redis redelivery, GX-97 autoscaling, init-container SIGTERM handling, and ai-server changes.
- Open design questions: none.
