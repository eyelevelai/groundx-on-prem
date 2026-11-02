## ADDED Requirements

### Requirement: Gunicorn waits for in-flight requests for the API's own timeout
The chart SHALL set gunicorn `graceful_timeout` in each of the five API gunicorn configs (`extract`, `layout`, `ranker`, `summary`, `workspace`) to that API's `groundx.<svc>.api.timeout` value (default 240 for summary, 120 for the others), so gunicorn finishes requests in flight after SIGTERM for as long as it lets one run.

#### Scenario: Default graceful timeout follows the API timeout (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** `summary` renders `graceful_timeout = 240` and `extract`, `layout`, `ranker` and `workspace` render `graceful_timeout = 120`

#### Scenario: An overridden timeout moves graceful_timeout with it (polarity: finalize success; catches)
- **WHEN** `ranker.api.timeout` is 200
- **THEN** the ranker gunicorn config renders `timeout = 200` and `graceful_timeout = 200`, not 120

#### Scenario: A request running 60 seconds after SIGTERM completes (polarity: finalize success; verified by a recorded local Docker run per API image)
- **WHEN** an API container started with the chart's start command and rendered gunicorn config receives SIGTERM while a 60-second request is running
- **THEN** the request completes with a response and the container then exits
- **AND** the same run against the previous chart's gunicorn config returns an empty reply 30 seconds after SIGTERM

### Requirement: API pods default their grace period to timeout plus 30 seconds
The chart SHALL render `terminationGracePeriodSeconds` on each of the five API Deployments as `groundx.<svc>.api.timeout + 30` when `replicas.gracePeriod` is not set (150 seconds, 270 for summary-api), and SHALL render `replicas.gracePeriod` when it is set on `extract.api` or `workspace.api`. `layout.api`, `ranker.api` and `summary.api` SHALL keep rejecting `replicas.gracePeriod`. `values.schema.json` SHALL NOT change. An idle API pod SHALL still stop immediately on SIGTERM.

#### Scenario: Derived default grace (polarity: finalize success)
- **WHEN** the chart is rendered with default values
- **THEN** `ranker-api` renders `terminationGracePeriodSeconds: 150` and `summary-api` renders 270

#### Scenario: Explicit grace keeps precedence on extract and workspace (polarity: skip unrelated repair path; must not block)
- **WHEN** `extract.api.replicas.gracePeriod` is 60
- **THEN** `extract-api` renders `terminationGracePeriodSeconds: 60`

#### Scenario: Grace follows an overridden timeout (polarity: finalize success; catches)
- **WHEN** `layout.api.timeout` is 200
- **THEN** `layout-api` renders `terminationGracePeriodSeconds: 230`

#### Scenario: Unsupported grace override is still rejected (polarity: reject before state)
- **WHEN** `ranker.api.replicas.gracePeriod` is set
- **THEN** schema validation fails and no manifest is rendered

### Requirement: Ranker-api task wait is capped by a chart-rendered environment variable
The chart SHALL render the container env var `RANKER_TASK_WAIT_SECONDS` on `ranker-api` only, with the value `max(1, groundx.ranker.api.timeout - 10)`, computed once in a chart helper. It SHALL NOT be a `config.py` key, so `ranker-config-py-map` and `ranker-inference` render unchanged. It is not a secret.

#### Scenario: Default cap (polarity: accept and enqueue)
- **WHEN** the chart is rendered with default values
- **THEN** the `ranker-api` container env contains `RANKER_TASK_WAIT_SECONDS` with value `110`

#### Scenario: Cap floors at one second (polarity: finalize success; catches)
- **WHEN** `ranker.api.timeout` is 5
- **THEN** the env value is `1`, not zero or negative

#### Scenario: Other APIs and the ranker GPU pod gain nothing (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart is rendered with default values
- **THEN** `summary-api`, `layout-api` and `extract-api` carry no `RANKER_TASK_WAIT_SECONDS`
- **AND** the `ranker-config-py-map` Secret and the `ranker-inference` Deployment are byte-identical to the previous chart

#### Scenario: Old and new images interoperate (polarity: finalize success; backward compatibility)
- **WHEN** the chart is deployed with a `ranker-api` image that does not read the variable
- **THEN** the variable is ignored and the pod behaves as before
- **AND** with a new image and the variable absent, the image uses its bounded built-in default of 110 seconds

### Requirement: API shutdown changes ship in the mirror with hand-patched snapshots
Every template changed by this capability SHALL be copied byte-for-byte into `helm/templates/`, and the affected helm-unittest snapshots SHALL be patched by hand and verified without `helm unittest -u`.

#### Scenario: Mirror and snapshots agree (polarity: finalize success)
- **WHEN** the gate `.build/bin/validate-helm.sh` runs
- **THEN** the template mirror check and every helm-unittest snapshot pass
