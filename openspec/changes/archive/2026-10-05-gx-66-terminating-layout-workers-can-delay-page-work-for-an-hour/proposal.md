## Why

When Kubernetes terminates a layout worker pod, the worker can keep taking page tasks and then disappear before finishing them. Layout Celery acknowledges a task only after it finishes, so an interrupted page waits for the broker's redelivery timeout (an hour by default) before it runs again. In the GX-66 incident, pages that were running on scaled-down `layout-map` and `layout-correct` pods ran again about an hour later and held three documents at the completion tail.

On `0.2.7` the layout workers have the same gap that the extract workers had before commit `d3c99a7b`: the container command runs `supervisord` through `sh -c` without `exec`, the Supervisor config sets no `stopwaitsecs` on `celery_worker_N`, and the pod falls back to the 30-second Kubernetes default grace period. The layout values schema also rejects `replicas.gracePeriod`, so an operator cannot raise the grace period today even though the ticket body says they can.

## What Changes

- Render `exec supervisord` as the container command for the five layout Celery workers (`correct`, `map`, `ocr`, `process`, `save`) and for `layout-inference`, so SIGTERM reliably reaches Supervisor and Celery, whatever the shell does with its last command. For `layout-inference` the `exec` goes after the existing `python /app/init-layout.py &&` step, immediately before `supervisord`.
- Default `terminationGracePeriodSeconds` to 900 for those six workloads; `layout.<service>.replicas.gracePeriod` overrides it per service.
- Set Supervisor `stopwaitsecs` on every `celery_worker_N` program in the layout Supervisor config to `max(1, gracePeriod - 30)` (870 at the default), read from the rendering service's own `replicas.gracePeriod`. The `celery_monitor` and `celery_health` programs of `layout-inference` keep their current configuration.
- Accept `gracePeriod` (integer, `minimum: 1`) under `layout.{correct,map,ocr,process,save,inference}.replicas` in both `src/groundx/values.schema.json` and its `helm/` mirror. `layout.api` is not a worker and does not gain the key.
- Mirror every changed template into `helm/` by hand (the byte-compare gate `verify_mirrors()` covers templates; the schema mirror is not covered).
- Add the tests as explicit-assert cases in the existing `src/groundx/tests/celery_test.yaml` and `src/groundx/tests/inference_test.yaml`, retarget one existing `celery_test` case to a workspace worker, and add one `helm/tests/layout_grace_period_test.yaml` case (design decision 10); patch the affected snapshot blocks by hand and commit them separately.
- No `preStop` hook is added. Celery's warm shutdown on SIGTERM is relied on; the uncommitted runtime shutdown test showed that a single-worker pod takes no new task after SIGTERM. The two-worker case took a new task 42 seconds after SIGTERM; it was escalated and resolved here by the Supervisor group (design decision 8).

Behavior that stays: ranker inference, summary inference, workspace workers and extract workers render unchanged. `layout-inference` shares `inference.yaml` with ranker and summary inference, so the grace period and `exec` additions are gated on the layout map prefix.

Backward compatible, no **BREAKING** change: `gracePeriod` is an optional new key and the default only lengthens how long a terminating pod may drain.

## Capabilities

### New Capabilities
- `layout-worker-graceful-shutdown`: the layout Celery workers and `layout-inference` receive SIGTERM through `exec supervisord`, render a 900-second default pod grace period overridable by `layout.<service>.replicas.gracePeriod`, and give each `celery_worker_N` a Supervisor stop wait of `max(1, gracePeriod - 30)` seconds.

### Modified Capabilities
<!-- None. queue-service-grace-period covers the Go queue services and is context only. -->

## Impact

- **Environments and blast radius.** Any cluster that upgrades to a chart carrying this change restarts its six layout Deployments (`layout-correct`, `-map`, `-ocr`, `-process`, `-save`, `-inference`) once, because the Supervisor ConfigMap content feeds the `supervisord-hash` pod annotation and the container command changes. Ranker, summary, workspace, extract and all Go services are not restarted by this change. Where an operator sets `layout.inference.updateStrategy: Recreate`, the `layout-inference` rollout can take up to the new grace period when a worker is mid-task; the PR body notes this. Upgrading terminates the old layout pods under their old spec (30-second grace, no `exec`), so a page in flight during the upgrade can still wait for the one-hour redelivery once; upgrade during low ingest or let the layout queues drain first.
- **Data and stateful resources.** None. No database, migration, secret or environment variable changes.
- **Operator-facing contract.** New optional `gracePeriod` key on six layout `replicas` blocks. The harness documentation (`groundx-studio-harness`, `values-yaml.md`) lists it in a separate PR that merges only after chart `0.2.7` is published.
- **Autoscaler caveat.** When the cluster autoscaler removes a node, its own maximum graceful-termination setting caps the effective grace period; this is documented, not changed here.
- **Rollback and roll-forward.** Roll back by reverting the chart commit or redeploying the previous chart version, which restores the 30-second default grace period and the current command (one more rolling restart of the six layout Deployments). Roll forward by raising or lowering `layout.<service>.replicas.gracePeriod`. Values files that set `gracePeriod` on a layout service fail schema validation on a chart version that predates this change.
- **Out of scope.** Ranker inference, summary inference and workspace workers have the same shutdown gap and are tracked in GX-91. Redis `visibility_timeout`, OOM and other forced-kill recovery (GX-61), the lost layout-webhook callback (GX-65), and the Go queue worker drain (FRA-114) are separate.
- **Open design questions.** None. The Supervisor group for a pod running more than one `celery_worker_N` is decided (design decision 8): the workers share one `[group:celery_workers]` section so they stop together.
