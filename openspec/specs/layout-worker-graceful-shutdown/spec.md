# layout-worker-graceful-shutdown Specification

## Purpose
TBD - created by archiving change gx-66-terminating-layout-workers-can-delay-page-work-for-an-hour. Update Purpose after archive.
## Requirements
### Requirement: Layout workers receive SIGTERM through exec supervisord
The chart SHALL render the container command of the five layout Celery workers (`layout-correct`, `layout-map`, `layout-ocr`, `layout-process`, `layout-save`) as `export PYTHONPATH=/app && exec supervisord -c /app/supervisord.conf`, and the container command of `layout-inference` as `export PYTHONPATH=/app:$PYTHONPATH && python /app/init-layout.py && exec supervisord -c /app/supervisord.conf`. Extract workers SHALL keep the command they render today. The startup commands of `ranker-inference`, `summary-inference` and the workspace workers are specified by the `worker-graceful-shutdown` capability.

#### Scenario: Layout Celery workers replace the shell (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** each of `layout-correct`, `layout-map`, `layout-ocr`, `layout-process` and `layout-save` has `exec supervisord` as the last command of its `command[2]` script

#### Scenario: layout-inference runs init before exec (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** the `layout-inference` command runs `python /app/init-layout.py` first and `exec supervisord` after it, so a failing init still stops the container before Supervisor starts

#### Scenario: Extract workers keep their startup command (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with `extract.enabled=true`
- **THEN** the extract workers render the same `exec supervisord` command as the previous chart

### Requirement: Layout worker pods default to a 900-second grace period
The chart SHALL render `terminationGracePeriodSeconds: 900` on the five layout Celery worker Deployments and on `layout-inference` when no grace period is set, and SHALL render the value of `layout.<service>.replicas.gracePeriod` on the Deployment of that service when it is set. The grace period of `ranker-inference`, `summary-inference` and the workspace workers is specified by the `worker-graceful-shutdown` capability.

#### Scenario: Default grace period (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** each of the six layout workloads has `terminationGracePeriodSeconds: 900`

#### Scenario: Override applies to one service only (polarity: finalize success)
- **WHEN** `layout.map.replicas.gracePeriod` is set to 120 and no other grace period is set
- **THEN** `layout-map` renders `terminationGracePeriodSeconds: 120`
- **AND** `layout-correct` still renders 900

#### Scenario: layout-inference accepts its own override (polarity: finalize success)
- **WHEN** `layout.inference.replicas.gracePeriod` is set to 120
- **THEN** `layout-inference` renders `terminationGracePeriodSeconds: 120`

#### Scenario: A layout override does not reach other inference services (polarity: skip unrelated repair path; must not block)
- **WHEN** `layout.inference.replicas.gracePeriod` is set to 120 and no ranker or summary grace period is set
- **THEN** `layout-inference` renders 120
- **AND** `ranker-inference` and `summary-inference` still render 900

### Requirement: Supervisor stop wait follows the pod grace period
The layout Supervisor config SHALL set `stopwaitsecs` to `max(1, gracePeriod - 30)` on every `celery_worker_N` program, where `gracePeriod` is the `replicas.gracePeriod` of the service that owns the config map and defaults to 900 when unset. The `celery_monitor` and `celery_health` programs of `layout-inference` SHALL NOT gain `stopwaitsecs`. The ranker, summary and workspace Supervisor configs are specified by the `worker-graceful-shutdown` capability.

#### Scenario: Default stop wait (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** every `celery_worker_N` program in each of the six layout Supervisor config maps has `stopwaitsecs=870`

#### Scenario: Stop wait follows the service's own override (polarity: finalize success)
- **WHEN** `layout.map.replicas.gracePeriod` is set to 120
- **THEN** the `layout-map` Supervisor config has `stopwaitsecs=90`
- **AND** the `layout-correct` Supervisor config still has `stopwaitsecs=870`

#### Scenario: Stop wait floors at one second (polarity: finalize success)
- **WHEN** `layout.map.replicas.gracePeriod` is set to 20
- **THEN** the `layout-map` Supervisor config has `stopwaitsecs=1`

#### Scenario: Every worker of a multi-worker pod carries the stop wait (polarity: finalize success)
- **WHEN** `layout.map.workers` is 2
- **THEN** both `celery_worker_1` and `celery_worker_2` in the `layout-map` Supervisor config have `stopwaitsecs=870`
- **AND** the config lists both programs in one `[group:celery_workers]` section, so Supervisor stops them together and neither takes a new task after SIGTERM

#### Scenario: layout-inference stop wait is derived from its own grace period (polarity: finalize success; catches)
- **WHEN** the chart is rendered with default values and no `layout.inference.replicas.gracePeriod`
- **THEN** the `layout-inference` `celery_worker_1` program has `stopwaitsecs=870`, not `stopwaitsecs=1` as a formula applied to an unset value would give

#### Scenario: Layout monitor and health programs are untouched (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** the `celery_monitor` and `celery_health` programs of `layout-inference` carry no `stopwaitsecs`

### Requirement: Values schema accepts gracePeriod on layout worker replicas
`src/groundx/values.schema.json` and `helm/values.schema.json` SHALL accept `gracePeriod` as an integer with `minimum: 1` under `layout.correct.replicas`, `layout.map.replicas`, `layout.ocr.replicas`, `layout.process.replicas`, `layout.save.replicas` and `layout.inference.replicas`. `layout.api.replicas` SHALL NOT accept it. The two schema files SHALL stay byte-identical.

#### Scenario: Valid gracePeriod renders on a worker block and on layout-inference (polarity: accept and enqueue)
- **WHEN** `layout.map.replicas.gracePeriod` is 120 and `layout.inference.replicas.gracePeriod` is 150
- **THEN** the chart validates and renders `layout-map` and `layout-inference` each with its own value

#### Scenario: A gracePeriod of zero is rejected before anything renders (polarity: reject before state)
- **WHEN** `layout.map.replicas.gracePeriod` is 0
- **THEN** schema validation fails with a minimum error and no manifest is rendered

#### Scenario: Schema surfaces stay identical (polarity: finalize success)
- **WHEN** the two schema files are compared
- **THEN** they are byte-identical

### Requirement: Existing values files keep validating and rendering
Values files that do not set `gracePeriod` SHALL keep validating. The only rendered differences from the previous chart for such files SHALL be the layout workloads' pod grace period, `exec` command, Supervisor `stopwaitsecs`, the `[group:celery_workers]` Supervisor section and the resulting `supervisord-hash` annotation. Rendered differences for ranker, summary and workspace workloads are specified by the `worker-graceful-shutdown` capability.

#### Scenario: Backward compatibility with values that omit gracePeriod (polarity: finalize success)
- **WHEN** a values file written for the previous chart, with no `gracePeriod` under `layout`, is rendered
- **THEN** it validates and renders
- **AND** the rendered extract workloads are unchanged from the previous chart

