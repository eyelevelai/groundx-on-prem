## Why

A layout-inference pod deleted while its image is loading or its models are initializing still starts Celery and keeps accepting page jobs until Kubernetes force-kills it (GX-115). The chart starts the container with `python /app/init-layout.py && exec supervisord`; the shell waits on `init-layout.py`, the shutdown signal arrives during that wait and is lost, and `supervisord` starts afterwards inside an already-terminating pod. GX-66 added `exec supervisord`, which only takes effect after `init-layout.py` completes, so it does not cover this window. In the 2026-10-15 FX load test on `groundx-prod-eks`, five pods deleted this way accepted more than 5,500 tasks after deletion began, while a pod deleted after startup shut down cleanly. Authority: the current Linear body for GX-115.

## What Changes

- In the layout-inference pod, run `python /app/init-layout.py` in a new init container (same image, working directory, `PYTHONPATH`, secret `envFrom`, config-models/config-volume/model-volume mounts, security context and CA env/mount as the main container), and start `supervisord` directly as PID 1 in the main container with no shell or init step in front of it. Applied in `src/groundx` and mirrored byte-for-byte into `helm/`.
- The ranker, summary, workspace and extract inference renders stay byte-identical to today.
- Update the `helm unittest` suite: retarget the existing layout-inference command assertions, add init-container and direct-`supervisord` assertions, and hand-patch the affected snapshots (never `-u`).
- Add a committed, hand-run minikube lifecycle script and stand-in image (Dockerfile beside the script, outside any path `bin/container` publishes, built only into minikube's local docker). It applies the chart's `helm template` output, changed only through Helm values, and proves both timings: delete during init means Celery never starts and zero tasks are consumed; delete after start means warm shutdown. It fails on the current chart and passes on the fix. It is not wired into pre-push.
- Accepted behavior (decision A): the init container gets no signal wrapper, so a pod deleted mid-init may stay Terminating until `init-layout.py` finishes or the grace period expires; it takes no tasks, so only scale-down is slower.
- Accepted residual risk: a pod deletion landing between init-container exit and `supervisord` installing its SIGTERM handler (sub-second) can still lose the signal, so that pod takes jobs until the grace-period SIGKILL. The same window exists for the five layout Celery workers. Accepted as a small risk at the plan gate. `shareProcessNamespace` was considered and rejected: killing `init-layout.py` mid-write would leave a truncated model file on the shared ReadWriteMany model cache, blocking every later layout pod.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `layout-worker-graceful-shutdown`: the requirement "Layout workers receive SIGTERM through exec supervisord" changes for layout-inference (init container plus `supervisord` as PID 1 instead of `init-layout.py && exec supervisord`); the layout Celery-worker `exec` commands and the "other workloads keep their startup command" scenario carry over. "Existing values files keep validating and rendering" is amended to permit the layout-inference init container and command as the only render diff.

## Impact

- Code: `src/groundx/templates/_helpers/app/layout-inference.tpl`, `src/groundx/templates/app/inference.yaml`, their `helm/` mirrors, `src/groundx/tests/inference_test.yaml` and its snapshots, plus the new minikube script and stand-in Dockerfile.
- Blast radius: any environment running a chart with layout inference enabled; a chart upgrade restarts the layout-inference Deployment once. No data or stateful resource is touched, and no values schema or API changes. The layout-inference image is used unchanged.
- Rollback: roll back the chart release, which restores the previous startup command. Roll-forward carries no migration.
- Pipeline limits: it never deploys. A human-run dev EKS round (including the "deleted while the image is still downloading" timing) follows outside the pipeline.
- Out of scope: stuck-document monitoring or recovery, Celery/Redis redelivery, GX-97 autoscaling, init-container SIGTERM handling, and ai-server changes.
- Open design questions: none.
