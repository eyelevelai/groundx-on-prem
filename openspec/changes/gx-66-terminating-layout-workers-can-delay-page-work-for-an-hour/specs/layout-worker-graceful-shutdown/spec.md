## ADDED Requirements

### Requirement: Layout workers receive SIGTERM through exec supervisord
The chart SHALL render the container command of the five layout Celery workers (`layout-correct`, `layout-map`, `layout-ocr`, `layout-process`, `layout-save`) as `export PYTHONPATH=/app && exec supervisord -c /app/supervisord.conf`, and the container command of `layout-inference` as `export PYTHONPATH=/app:$PYTHONPATH && python /app/init-layout.py && exec supervisord -c /app/supervisord.conf`. Workspace workers, extract workers, `ranker-inference` and `summary-inference` SHALL keep the commands they render today.

#### Scenario: Layout Celery workers replace the shell (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** each of `layout-correct`, `layout-map`, `layout-ocr`, `layout-process` and `layout-save` has `exec supervisord` as the last command of its `command[2]` script

#### Scenario: layout-inference runs init before exec (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** the `layout-inference` command runs `python /app/init-layout.py` first and `exec supervisord` after it, so a failing init still stops the container before Supervisor starts

#### Scenario: Other workloads keep their startup command (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with `workspace.enabled=true`
- **THEN** `workspace-workspace` keeps `export PYTHONPATH=/app && supervisord -c /app/supervisord.conf` with no `exec`
- **AND** `ranker-inference` and `summary-inference` keep their current command with no `exec`

### Requirement: Layout worker pods default to a 900-second grace period
The chart SHALL render `terminationGracePeriodSeconds: 900` on the five layout Celery worker Deployments and on `layout-inference` when no grace period is set, and SHALL render the value of `layout.<service>.replicas.gracePeriod` on the Deployment of that service when it is set. `ranker-inference` and `summary-inference` SHALL NOT gain a `terminationGracePeriodSeconds` field from this change.

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

#### Scenario: Ranker and summary inference gain no grace period (polarity: skip unrelated repair path; catches)
- **WHEN** the chart is rendered with default values
- **THEN** `ranker-inference` and `summary-inference` render no `terminationGracePeriodSeconds`, even though they share `inference.yaml` with `layout-inference`

### Requirement: Supervisor stop wait follows the pod grace period
The layout Supervisor config SHALL set `stopwaitsecs` to `max(1, gracePeriod - 30)` on every `celery_worker_N` program, where `gracePeriod` is the `replicas.gracePeriod` of the service that owns the config map and defaults to 900 when unset. The `celery_monitor` and `celery_health` programs of `layout-inference` SHALL NOT gain `stopwaitsecs`. The `ranker-inference` and `summary-inference` Supervisor configs SHALL NOT gain `stopwaitsecs`.

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

#### Scenario: Non-worker programs and other inference services are untouched (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** the `celery_monitor` and `celery_health` programs of `layout-inference` carry no `stopwaitsecs`
- **AND** the `ranker-inference` and `summary-inference` Supervisor configs contain no `stopwaitsecs`

### Requirement: Values schema accepts gracePeriod on layout worker replicas
`src/groundx/values.schema.json` and `helm/values.schema.json` SHALL accept `gracePeriod` as an integer with `minimum: 1` under `layout.correct.replicas`, `layout.map.replicas`, `layout.ocr.replicas`, `layout.process.replicas`, `layout.save.replicas` and `layout.inference.replicas`. `layout.api.replicas` SHALL NOT accept it. The two schema files SHALL stay byte-identical.

#### Scenario: Valid gracePeriod renders on every worker block (polarity: accept and enqueue)
- **WHEN** each of the six blocks sets a different `replicas.gracePeriod` of at least 1
- **THEN** the chart validates and renders each Deployment with its own value

#### Scenario: Zero and non-integer values are rejected before anything renders (polarity: reject before state)
- **WHEN** `layout.map.replicas.gracePeriod` is 0, or is a string
- **THEN** schema validation fails and no manifest is rendered

#### Scenario: layout.api rejects gracePeriod (polarity: reject before state; catches)
- **WHEN** `layout.api.replicas.gracePeriod` is set
- **THEN** schema validation fails with an additional-properties error, because `layout.api` is not a worker

#### Scenario: Schema surfaces stay identical (polarity: finalize success)
- **WHEN** the two schema files are compared
- **THEN** they are byte-identical

### Requirement: Existing values files keep validating and rendering
Values files that do not set `gracePeriod` SHALL keep validating. The only rendered differences from the previous chart for such files SHALL be the layout workloads' pod grace period, `exec` command, Supervisor `stopwaitsecs` and the resulting `supervisord-hash` annotation.

#### Scenario: Backward compatibility with values that omit gracePeriod (polarity: finalize success)
- **WHEN** a values file written for the previous chart, with no `gracePeriod` under `layout`, is rendered
- **THEN** it validates and renders
- **AND** the rendered `ranker-inference`, `summary-inference`, workspace and extract workloads are unchanged from the previous chart
