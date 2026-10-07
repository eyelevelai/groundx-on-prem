# ranker-inference-autoscaling Specification

## Purpose
TBD - created by archiving change fix-ranker-inference-hpa-readiness. Update Purpose after archive.
## Requirements
### Requirement: Ranker Inference HPA Uses Windowed Busy Time

Ranker inference HPA SHALL use a windowed busy-time inference metric for
pod-specific autoscaling pressure.

#### Scenario: Ranker inference HPA is rendered

- **GIVEN** ranker inference HPA is enabled
- **WHEN** the chart renders the ranker inference HPA
- **THEN** it includes `ranker-inference:throughput`
- **AND** it includes `ranker-inference:inference` as the pod-specific metric
- **AND** the default HPA target is below `1`.

#### Scenario: Ranker inference busy config is rendered

- **GIVEN** ranker inference is enabled
- **AND** ranker inference HPA is enabled
- **WHEN** the chart renders `config.yaml`
- **THEN** `metrics.inference` includes `ranker-inference`
- **AND** its `busyWindowSeconds` defaults to `60`
- **AND** `metrics.task` does not include `ranker-inference`
- **AND** it does not render `metrics.sessions.ranker-inference`.

#### Scenario: Ranker inference busy config is omitted when HPA is disabled

- **GIVEN** ranker inference is enabled
- **AND** ranker inference HPA is disabled
- **WHEN** the chart renders `config.yaml`, ranker `config.py`, and HPA resources
- **THEN** `metrics.inference` does not include ranker busy config
- **AND** ranker `config.py` does not enable `metricsBusyWindowSeconds`
- **AND** no ranker inference HPA is rendered.

#### Scenario: Ranker config receives busy window

- **GIVEN** ranker inference is enabled
- **AND** ranker inference HPA is enabled
- **WHEN** the chart renders ranker `config.py`
- **THEN** it includes `metricsBusyWindowSeconds=60`
- **AND** `metricsBroker` points at the metrics cache.

#### Scenario: Offline monitor events do not create busy intervals

- **GIVEN** ranker inference busy metrics are enabled
- **WHEN** a Celery monitor reports a worker offline
- **THEN** the status writer does not create a new busy-start key
- **AND** no busy bucket is written from that offline event.

#### Scenario: Ranker cache override does not move busy metrics

- **GIVEN** ranker inference is enabled
- **AND** `ranker.cache.addr` is set
- **WHEN** the chart renders ranker config and `config.yaml`
- **THEN** ranker search brokers use the ranker cache
- **AND** `metricsBroker` still uses the metrics cache
- **AND** `metrics.sessions.ranker-inference` is not rendered.

#### Scenario: Published chart mirror stays aligned

- **WHEN** the ranker inference HPA and config templates are compared
- **THEN** `src/groundx` and `helm` contain the same windowed busy metric
  contract.

### Requirement: Other Ranker Surfaces Stay Unchanged

This change SHALL NOT modify ranker API HPA behavior, node provisioning,
secrets, search behavior, ranking behavior, or stateful resources.

#### Scenario: The implementation diff is reviewed

- **WHEN** the implementation diff is reviewed
- **THEN** there is no ranker API capacity metric change
- **AND** other Celery task backlog metrics are unchanged
- **AND** deployment still requires explicit approval.

