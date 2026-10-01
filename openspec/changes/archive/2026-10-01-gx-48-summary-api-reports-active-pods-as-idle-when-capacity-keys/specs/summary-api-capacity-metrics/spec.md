## ADDED Requirements

### Requirement: The summary-api inference capacity value is per gunicorn process

The `summary-api` entry of `metrics.inference` in the rendered `config.yaml` SHALL carry
`tokensPerMinute = max(1, threshold / workers)` with integer division, where `threshold` is
`groundx.summary.api.threshold` and `workers` is `groundx.summary.api.workers`. The entry SHALL still
be omitted when the threshold is `0`. No other metrics entry SHALL change.

Polarity: `finalize success` (the per-process value is rendered) and `skip unrelated repair path`
(no other entry is touched).

#### Scenario: Two workers halve the inference value and leave the per-pod throughput entry alone

- **GIVEN** the chart rendered with `summary.api.workers: 2` and the default `threads`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `summary-api` entry under `metrics.inference` has `tokensPerMinute: 9600`
- **AND** the `summary-api` entry under `metrics.throughput` still has `tokensPerMinute: 19200`
  (the per-pod value, not halved)

#### Scenario: One worker (default) renders exactly as before

- **GIVEN** the chart rendered with `summary.api.workers` unset or `1`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `summary-api` inference value equals the value `groundx.summary.api.threshold` returns,
  and every existing snapshot whose fixture does not set `workers` greater than 1 is unchanged
  (the opposite outcome, a changed default snapshot, must not occur)

#### Scenario: Result is never below 1

- **GIVEN** a `threshold` smaller than `workers`
- **WHEN** the value is computed
- **THEN** the rendered `tokensPerMinute` is `1`, never `0` and never a render error from dividing by
  zero, because a `0` value would be read by cashbot-go as "no throughput metric"
  (`inf.TokensPerMinute > 0` at `metrics.go:364`)

### Requirement: `src/groundx` and `helm/` render the same value

`helm/templates/resources/config-yaml.yaml` SHALL be byte-identical to
`src/groundx/templates/resources/config-yaml.yaml`.

#### Scenario: Mirror renders the per-process value

- **GIVEN** `helm/` rendered with `summary.api.workers: 2`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `summary-api` inference `tokensPerMinute` equals the `src/groundx` render (`9600`), not
  the per-pod `19200`

### Requirement: Backward compatibility during rollout

The value SHALL be documented as correct only together with ai-server per-process capacity ids
(ai-server#66); behavior with `workers: 1` SHALL be identical whichever side rolls first.

#### Scenario: Default deployment is rollout-order independent

- **GIVEN** a deployment with `summary.api.workers: 1`
- **WHEN** the chart change and ai-server#66 roll in either order
- **THEN** the autoscaler's per-process denominator and per-pod/per-process record count agree, because
  pods and processes are the same number
