# worker-graceful-shutdown Specification

## Purpose
TBD - created by archiving change gx-91-terminating-ranker-summary-and-workspace-workers-can-drop. Update Purpose after archive.
## Requirements
### Requirement: Ranker, summary and workspace workers receive SIGTERM through exec supervisord
The chart SHALL render the container command of `ranker-inference` and `summary-inference` as `export PYTHONPATH=/workspace:$PYTHONPATH && exec supervisord -c /workspace/supervisord.conf`, and the container command of the five workspace worker Deployments (`workspace-cleanup`, `workspace-command`, `workspace-provision`, `workspace-publish`, `workspace-workspace`) as `export PYTHONPATH=/app && exec supervisord -c /app/supervisord.conf`, so Supervisor is PID 1 and receives the pod's SIGTERM.

#### Scenario: Ranker and summary inference replace the shell (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** `ranker-inference` and `summary-inference` each have `exec supervisord` as the last command of `command[2]`

#### Scenario: Every workspace worker replaces the shell (polarity: finalize success)
- **WHEN** the chart is rendered with `workspace.enabled=true`
- **THEN** each of the five workspace worker Deployments has `exec supervisord` as the last command of `command[2]`
- **AND** none of them still renders `supervisord` without `exec`

#### Scenario: Extract, layout and layout-inference commands are unchanged (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** the extract and layout Celery workers render the same `exec supervisord` command as the previous chart
- **AND** the `layout-inference` command is unchanged from the previous chart

### Requirement: Ranker, summary and workspace worker pods default to a 900-second grace period
The chart SHALL render `terminationGracePeriodSeconds: 900` on `ranker-inference`, `summary-inference` and the five workspace worker Deployments when no grace period is set, and SHALL render the value of `replicas.gracePeriod` of that service on its Deployment when it is set. The default SHALL NOT depend on the service name or map prefix of a Deployment rendered by `celery.yaml` or `inference.yaml`.

#### Scenario: Default grace period (polarity: finalize success)
- **WHEN** the chart is rendered with `workspace.enabled=true` and no `gracePeriod`
- **THEN** `ranker-inference`, `summary-inference` and each of the five workspace worker Deployments render `terminationGracePeriodSeconds: 900`

#### Scenario: Override applies to one service only (polarity: finalize success)
- **WHEN** `ranker.inference.replicas.gracePeriod` is 120, `summary.inference.replicas.gracePeriod` is 150 and `workspace.provision.replicas.gracePeriod` is 120
- **THEN** `ranker-inference` renders 120, `summary-inference` renders 150 and `workspace-provision` renders 120
- **AND** `workspace-command` and `layout-inference` still render 900

#### Scenario: Extract and layout grace periods are unchanged (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** the extract and layout Deployments render the same `terminationGracePeriodSeconds` as the previous chart

### Requirement: Supervisor stop wait follows the pod grace period
The ranker, summary and workspace Supervisor configs SHALL set `stopwaitsecs` to `max(1, gracePeriod - 30)` on every `celery_worker_N` program, where `gracePeriod` is the `replicas.gracePeriod` of the service that owns the config map and defaults to 900 when unset. The `celery_monitor` and `celery_health` programs SHALL NOT gain `stopwaitsecs`.

#### Scenario: Default stop wait (polarity: finalize success)
- **WHEN** the chart is rendered with `workspace.enabled=true` and no `gracePeriod`
- **THEN** every `celery_worker_N` program in the ranker, summary and five workspace Supervisor config maps has `stopwaitsecs=870`

#### Scenario: Stop wait follows the service's own override (polarity: finalize success)
- **WHEN** `ranker.inference.replicas.gracePeriod` is 120 and `workspace.provision.replicas.gracePeriod` is 120
- **THEN** the ranker and `workspace-provision` Supervisor configs have `stopwaitsecs=90`
- **AND** the summary and `workspace-command` Supervisor configs still have `stopwaitsecs=870`

#### Scenario: Stop wait floors at one second (polarity: finalize success)
- **WHEN** `summary.inference.replicas.gracePeriod` is 20
- **THEN** the summary Supervisor config has `stopwaitsecs=1`

#### Scenario: Unset grace period never floors the stop wait (polarity: finalize success; catches)
- **WHEN** the chart is rendered with default values and no `ranker.inference.replicas.gracePeriod`
- **THEN** the ranker `celery_worker_1` program has `stopwaitsecs=870`, not the `stopwaitsecs=1` that the formula gives when applied to an unset value

#### Scenario: Monitor and health programs are untouched (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** the `celery_monitor` and `celery_health` programs of the ranker and summary Supervisor configs carry no `stopwaitsecs`

### Requirement: Every worker of a pod stops together through one Supervisor group
Each ranker, summary and workspace Supervisor config SHALL render exactly one `[group:celery_workers]` section whose `programs` lists every `celery_worker_N` program of that config, in order, so Supervisor signals all of them at once. `celery_monitor` and `celery_health` SHALL stay outside the group.

#### Scenario: Ranker at its default 14 workers (polarity: finalize success; catches)
- **WHEN** the chart is rendered with default values
- **THEN** the ranker Supervisor config has 14 `celery_worker_N` programs, each with `stopwaitsecs=870`
- **AND** one `[group:celery_workers]` section lists `celery_worker_1` through `celery_worker_14`, not only the first

#### Scenario: Raised worker counts resize the group (polarity: finalize success; catches)
- **WHEN** `ranker.inference.workers` is 3, `summary.inference.workers` is 2 and `workspace.provision.workers` is 3
- **THEN** each config's group lists exactly its own workers
- **AND** no config carries a `stopwaitsecs` beyond its own worker count

#### Scenario: Single-worker pods get a one-program group (polarity: finalize success)
- **WHEN** the chart is rendered with `workspace.enabled=true` and default worker counts
- **THEN** the summary and each workspace Supervisor config has `[group:celery_workers]` listing only `celery_worker_1`

#### Scenario: Monitor and health stay ungrouped (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** the ranker and summary groups list no `celery_monitor` or `celery_health` program

### Requirement: Values schema accepts gracePeriod on ranker and summary inference replicas
`src/groundx/values.schema.json` and `helm/values.schema.json` SHALL accept `gracePeriod` as an integer with `minimum: 1` under `ranker.inference.replicas` and `summary.inference.replicas`, in the existing alphabetical property order. The workspace worker `replicas` schema SHALL stay unchanged. The two schema files SHALL stay byte-identical.

#### Scenario: Valid gracePeriod validates and renders (polarity: accept and enqueue)
- **WHEN** `ranker.inference.replicas.gracePeriod` is 120 and `summary.inference.replicas.gracePeriod` is 150
- **THEN** the chart validates and renders each Deployment with its own value

#### Scenario: A gracePeriod of zero is rejected before anything renders (polarity: reject before state)
- **WHEN** `ranker.inference.replicas.gracePeriod` or `summary.inference.replicas.gracePeriod` is 0
- **THEN** schema validation fails with a minimum error and no manifest is rendered

#### Scenario: Schema surfaces stay identical (polarity: finalize success)
- **WHEN** the two schema files are compared
- **THEN** they are byte-identical

### Requirement: Helm mirror stays identical to the source chart
Every template changed by this capability SHALL be copied byte-for-byte into `helm/templates/` in the same change.

#### Scenario: Template trees match (polarity: finalize success)
- **WHEN** `src/groundx/templates` and `helm/templates` are compared
- **THEN** they are identical

### Requirement: Existing values files keep validating and rendering
Values files that do not set `gracePeriod` SHALL keep validating. The only rendered differences from the previous chart for such files SHALL be, for ranker, summary and workspace workloads, the pod grace period, the `exec` command, Supervisor `stopwaitsecs`, the `[group:celery_workers]` section and the resulting `supervisord-hash` annotation.

#### Scenario: Backward compatibility with values that omit gracePeriod (polarity: finalize success)
- **WHEN** a values file written for the previous chart, with no `gracePeriod` under `ranker`, `summary` or `workspace`, is rendered
- **THEN** it validates and renders
- **AND** the rendered extract, layout, Go and API workloads are unchanged from the previous chart

### Requirement: Shutdown behavior is proven on the real images before release
Before the change is released, a local-cluster test and then a validation-infra EKS test SHALL run the real ranker image at its default 14 workers, the summary image and one workspace worker, send each pod SIGTERM while a task runs, and record the result in the change folder. The test SHALL show that no worker starts a task after SIGTERM and that a running task shorter than `stopwaitsecs` finishes within the grace period, and it SHALL fail on the chart before this change.

#### Scenario: Ranker with 14 workers drains (polarity: finalize success)
- **WHEN** the ranker pod at its default worker count receives SIGTERM while a task runs
- **THEN** no worker starts a task after SIGTERM and the running task finishes before the pod exits

#### Scenario: Summary solo pool drains (polarity: finalize success)
- **WHEN** the summary pod receives SIGTERM while a task runs
- **THEN** it takes no new task and finishes the running task before the pod exits
- **AND** a failure here stops the change for a plan amendment on the summary app's own SIGTERM handler, not a chart workaround

#### Scenario: The previous chart fails the same test (polarity: reject before state)
- **WHEN** the same test runs against the chart before this change
- **THEN** at least one pod takes a task after SIGTERM or loses its running task

