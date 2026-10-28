## Why

When Kubernetes terminates a ranker-inference, summary-inference, or workspace worker pod, the worker can lose the task it is running: the container command does not hand SIGTERM to Supervisor, Supervisor waits only its 10-second default before killing the Celery worker, and the pod gets the 30-second Kubernetes default. These workers acknowledge a task when it starts, so a task killed mid-run is not redelivered. Layout workers received the same fix under GX-66 (and GX-115 for inference); this change closes the gap for the remaining worker pods now, before more autoscaling and rollout traffic hits them. Task loss on these services has not been observed; the configuration gap is confirmed.

## What Changes

- ranker-inference, summary-inference, and the five workspace-runner worker Deployments (cleanup, command, provision, publish, workspace) start with `exec supervisord`, so the stop signal reaches Supervisor and Celery enters warm shutdown.
- Each of these Deployments renders `terminationGracePeriodSeconds` defaulting to 900 seconds, overridable per service through `replicas.gracePeriod`. The grace-period default and `exec` are no longer limited to extract and layout.
- Every `celery_worker_N` program in the ranker, summary, and workspace Supervisor configs sets `stopwaitsecs = max(1, grace - 30)`, so it ends before the pod grace period.
- Each of those Supervisor configs renders one `[group:celery_workers]` listing every `celery_worker_N`, so all workers in a pod receive SIGTERM together (ranker-inference defaults to 14 workers). `celery_monitor` and `celery_health` stay outside the group.
- `values.schema.json` accepts `gracePeriod` (integer, minimum 1) under `ranker.inference.replicas` and `summary.inference.replicas`. Workspace worker replicas already accept it. `src/groundx` and `helm/` schema files stay byte-identical.
- `values.yaml` comments document the new default and override.
- The `helm/` mirror is synced by hand for every template change, as `verify_mirrors()` requires.
- Tests: `celery_test` and `inference_test` gain exec, grace, stop-wait, and group cases (including the ranker at its default worker count); five hand-patched snapshots (`celery_test`, `inference_test`, `ranker_test`, `workspace_test`, `resources_test`), never regenerated with `-u`.
- Shutdown proof: a local, then EKS, test on the real ranker image (14 workers), the summary image, and one workspace worker, showing no worker starts a task after pod SIGTERM and a running task finishes within the grace period. It must fail (RED) on the current chart. EKS validation is human-run (this repo is privileged).

Not changing: layout and layout-inference workers (GX-66), extract workers, `acks_late`, broker `visibility_timeout`, recovery from OOM or other forced kills, and FraudX production values. No secret, env-var, SQL, or Kafka change.

## Capabilities

### New Capabilities
- `worker-graceful-shutdown`: ranker-inference, summary-inference, and workspace worker pods receive SIGTERM through `exec supervisord`, default to a 900-second grace period overridable via `replicas.gracePeriod`, derive `stopwaitsecs` from that grace period, stop all Celery workers in a pod together through one Supervisor group, and are accepted by the values schema.

### Modified Capabilities
- `layout-worker-graceful-shutdown`: its clauses stating that rendered ranker-inference, summary-inference, workspace, and extract workloads are unchanged from the previous chart are superseded for ranker, summary, and workspace (extract stays unchanged).

## Impact

- Code: `src/groundx/templates/app/celery.yaml`, `templates/app/inference.yaml`, `templates/_helpers/app/ranker-inference.tpl` and `summary-inference.tpl`, `templates/resources/{ranker,summary,workspace}-supervisord-conf.yaml`, `values.schema.json`, `values.yaml`, the `helm/` mirror of each, helm-unittest suites and five snapshots.
- Blast radius and rollout: every environment that upgrades to the 0.2.8 chart line restarts the ranker, summary, and five workspace Deployments once (command and supervisord ConfigMap hash change). After that, a rollout drain or scale-down waits for in-flight tasks, bounded by the longest running task up to the grace period (900 s default), so rollouts of these pods can take longer; summary on `Recreate` is down for the drain time plus model load. The autoscaler's 600 s caveat applies. No stateful resource (database, file, search, stream) is touched.
- Summary app signal handling: the summary app installs its own import-time SIGTERM handler (ai-server `summary/tasks/inference.py:45`). If the local/EKS shutdown test shows summary still takes a task after SIGTERM or does not finish its running task, the pipeline stops for a plan amendment deciding on an ai-server change (out of scope today).
- Rollback and roll-forward: roll back by redeploying the previous chart version (pods return to the 30-second behavior, which only reopens the task-loss gap); roll forward by setting `replicas.gracePeriod` lower per service. A published 0.2.7 chart rejects `ranker.inference.replicas.gracePeriod` and `summary.inference.replicas.gracePeriod` under its strict schema, so the key is only valid on the 0.2.8 line.
- Environments: any install that upgrades to the 0.2.8 chart line; this change is based on and targets the 0.2.8 branch, not main/master. No production values are edited here.
- Downstream: the `groundx-studio-harness` docs level follows in a separate repo after this level reaches verify.
- Open design questions: none.

## Amendments

### 2026-10-22

- GX-66 shipped the fix for the layout workers. GX-115 covers `layout-inference` and is in review, not merged.
- The cause that a shell wrapper does not forward SIGTERM to Supervisor is suspected and unverified on these images. The fix (`exec supervisord`, the grace period, the Supervisor stop settings) holds either way.
- The `Why` section above is left as originally written and overstates the above.
- The archived `specs/worker-graceful-shutdown/spec.md` in this change still carries the literal layout-inference command in its must-not-block scenario. It is left as-is because archives are append-only. The live spec at `openspec/specs/worker-graceful-shutdown/spec.md` now says the command is unchanged from the previous chart, because GX-115 replaces that command.
