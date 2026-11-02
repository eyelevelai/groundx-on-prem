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

### Requirement: Ranker and workspace worker pods default to a 900-second grace period, summary to 300 seconds
The chart SHALL render `terminationGracePeriodSeconds: 900` on `ranker-inference` and the five workspace worker Deployments and `terminationGracePeriodSeconds: 300` on `summary-inference` when no grace period is set, and SHALL render the value of `replicas.gracePeriod` of that service on its Deployment when it is set. The summary default stays 300 seconds, unchanged by the summary worker's engine shutdown; Celery's solo pool, which summary runs, enforces no task time limit, so a summary task still running at the stop wait is killed, and the summary API stops waiting for a result after 240 seconds, so such a task no longer has a caller. Each service's default grace period SHALL be defined once, in the shared Celery worker definition, and that single value SHALL feed both the Deployment's `terminationGracePeriodSeconds` and the Supervisor stop wait. The default SHALL NOT depend on the service name or map prefix of a Deployment rendered by `celery.yaml` or `inference.yaml`.

#### Scenario: Default grace period (polarity: finalize success)
- **WHEN** the chart is rendered with `workspace.enabled=true` and no `gracePeriod`
- **THEN** `ranker-inference` and each of the five workspace worker Deployments render `terminationGracePeriodSeconds: 900`
- **AND** `summary-inference` renders `terminationGracePeriodSeconds: 300`

#### Scenario: Override applies to one service only (polarity: finalize success)
- **WHEN** `ranker.inference.replicas.gracePeriod` is 120, `summary.inference.replicas.gracePeriod` is 150 and `workspace.provision.replicas.gracePeriod` is 120
- **THEN** `ranker-inference` renders 120, `summary-inference` renders 150 and `workspace-provision` renders 120
- **AND** `workspace-command` and `layout-inference` still render 900

#### Scenario: Extract and layout grace periods are unchanged (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** the extract and layout Deployments render the same `terminationGracePeriodSeconds` as the previous chart

### Requirement: Supervisor stop wait follows the pod grace period
The ranker, summary and workspace Supervisor configs SHALL set `stopwaitsecs` to `max(1, gracePeriod - 30)` on every `celery_worker_N` program, where `gracePeriod` is the `replicas.gracePeriod` of the service that owns the config map and defaults to that service's default grace period when unset (900, or 300 for summary). The `celery_monitor` and `celery_health` programs SHALL NOT gain `stopwaitsecs`.

#### Scenario: Default stop wait (polarity: finalize success)
- **WHEN** the chart is rendered with `workspace.enabled=true` and no `gracePeriod`
- **THEN** every `celery_worker_N` program in the ranker and five workspace Supervisor config maps has `stopwaitsecs=870`
- **AND** every `celery_worker_N` program in the summary Supervisor config map has `stopwaitsecs=270`

#### Scenario: Stop wait follows the service's own override (polarity: finalize success)
- **WHEN** `ranker.inference.replicas.gracePeriod` is 120 and `workspace.provision.replicas.gracePeriod` is 120
- **THEN** the ranker and `workspace-provision` Supervisor configs have `stopwaitsecs=90`
- **AND** the summary Supervisor config still has `stopwaitsecs=270` and `workspace-command` still has `stopwaitsecs=870`

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
Each extract, ranker, summary and workspace Supervisor config SHALL render exactly one `[group:celery_workers]` section whose `programs` lists every `celery_worker_N` program of that config, in order, so Supervisor signals all of them at once. `celery_monitor` and `celery_health` SHALL stay outside the group.

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

#### Scenario: Extract workers at two or more per pod stop together (polarity: finalize success; catches)
- **WHEN** `extract.agent.workers`, `extract.download.workers` or `extract.save.workers` is 2 or more
- **THEN** that service's Supervisor config has one `[group:celery_workers]` listing every `celery_worker_N` in order, so Supervisor does not stop them one after another

#### Scenario: Extract services with one worker also render the group (polarity: finalize success)
- **WHEN** the chart is rendered with `extract.enabled=true` and default worker counts
- **THEN** each extract Supervisor config has `[group:celery_workers]` listing only `celery_worker_1`

#### Scenario: Extract stop wait is unchanged by the group (polarity: skip unrelated repair path; must not block)
- **WHEN** `extract.agent.replicas.gracePeriod` is 120 and `extract.agent.workers` is 2
- **THEN** both extract-agent programs keep `stopwaitsecs=90` and the extract-agent Deployment keeps `terminationGracePeriodSeconds: 120`

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
Before the change is released, shutdown behavior SHALL be proven in two runs, each recorded in the change folder. A local-cluster test SHALL apply the ranker (default 14 workers), summary and one workspace Deployment rendered by the chart, changed only in image, init containers, GPU and resource requests, tolerations, affinity, probes and volumes, on stand-in images built on each real image's base and Supervisor package (summary carrying the summary app's import-time SIGTERM handler), send each pod SIGTERM while a task runs, show that no worker starts a task after SIGTERM and that a running task shorter than `stopwaitsecs` finishes within the grace period, and SHALL fail on the chart before this change. A validation-infra EKS test SHALL then run the real ranker image at its default 14 workers and the real summary image on GPU nodes with this chart, send each pod SIGTERM while tasks run, show the same two properties, and complete an end-to-end ingest, search and summary afterwards; it SHALL also show a real workspace worker shutting down warm.

#### Scenario: Ranker with 14 workers drains (polarity: finalize success)
- **WHEN** the ranker pod at its default worker count receives SIGTERM while a task runs
- **THEN** no worker starts a task after SIGTERM and the running task finishes before the pod exits

#### Scenario: Summary solo pool drains (polarity: finalize success)
- **WHEN** the summary pod receives SIGTERM while a task runs
- **THEN** it takes no new task and finishes the running task before the pod exits
- **AND** a failure here stops the change for a plan amendment on the summary app's own SIGTERM handler, not a chart workaround
- **AND** on a summary image that shuts its engine down in Celery's worker shutdown hook the worker exits with status 0 and is not killed at its stop wait

#### Scenario: The previous chart fails the same test (polarity: reject before state)
- **WHEN** the local-cluster test runs against the chart before this change
- **THEN** at least one pod takes a task after SIGTERM or loses its running task

### Requirement: Celery worker shutdown setup is defined once in a shared chart helper
The chart SHALL define, in one shared helper under `templates/_helpers/app/`, for every Celery worker service rendered through `celery.yaml` and `inference.yaml`: the service's default grace period, the Supervisor stop wait `max(1, gracePeriod - 30)`, the `[group:celery_workers]` section, the `export PYTHONPATH=... && exec supervisord -c .../supervisord.conf` container command and the optional startup step rendered as an init container. The five `*-supervisord-conf.yaml` files, `celery.yaml` and `inference.yaml` SHALL call that helper and SHALL NOT compute a default grace period or a stop wait themselves. A Celery worker service's rendered grace period, stop wait, worker programs, group and start command SHALL be byte-identical to the previous chart for the value combinations default values, `replicas.gracePeriod` set on every worker family, cache type valkey, `imageType: chainguard` (`values/chainguard/values.yaml`), two and three workers per family, and `mode: ingest`, except that each extract Supervisor config gains `[group:celery_workers]` and its Deployment's `supervisord-hash` changes with it. The `download-model` init container and every other non-Celery workload SHALL be untouched. The shared start command SHALL keep the shell form so Supervisor is PID 1 through `exec`.

#### Scenario: Every Celery worker render matches the previous chart (polarity: finalize success; must not block)
- **WHEN** `.build/bin/verify-celery-render-identity.py` renders the base commit and the working tree for each listed value combination
- **THEN** every Celery worker Deployment and `*-supervisord-conf-map` ConfigMap is byte-identical to the base render, except the extract Supervisor config maps and the `supervisord-hash` line of the extract Deployments
- **AND** the script exits 0

#### Scenario: A shared default that is wrong for one service is caught (polarity: finalize failure; catches)
- **WHEN** a shared definition applies the 900-second default to `summary-inference`, where the previous chart rendered 300
- **THEN** the identity script reports the `summary-inference` Deployment and Supervisor config as not byte-identical and exits non-zero

#### Scenario: A change beyond the extract group is caught (polarity: finalize failure; catches)
- **WHEN** an extract Supervisor config differs from the previous chart in anything other than the added group section
- **THEN** the identity script exits non-zero naming that config map

#### Scenario: Defaults and stop wait are not computed per file (polarity: reject before state)
- **WHEN** `extract-supervisord-conf.yaml`, `layout-supervisord-conf.yaml`, `ranker-supervisord-conf.yaml`, `summary-supervisord-conf.yaml`, `workspace-supervisord-conf.yaml`, `celery.yaml` and `inference.yaml` are searched for a literal default grace period or the `sub $gracePeriod 30` calculation
- **THEN** none matches

#### Scenario: Extract-agent preStop plus the grouped stop wait fit in the grace period (polarity: finalize success)
- **WHEN** `extract.agent.workers` is the tested count and the grace period is the default 900
- **THEN** the extract-agent `stopwaitsecs` is 870, leaving 30 seconds for the preStop hook, whose measured run time at that worker count is recorded in the change folder and is below 30 seconds

#### Scenario: The download-model init container is untouched (polarity: skip unrelated repair path; must not block)
- **WHEN** `inference.yaml` is diffed against the base commit
- **THEN** the `download-model` init container block has no changed line

#### Scenario: Helm mirror stays identical (polarity: finalize success)
- **WHEN** `src/groundx/templates` and `helm/templates` are compared after the change
- **THEN** they are identical

