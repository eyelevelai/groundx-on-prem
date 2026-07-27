## ADDED Requirements

### Requirement: Ranker Inference HPA Uses Celery Queue Back-Pressure

Ranker inference HPA SHALL use the existing Celery task backlog metric for
pod-specific autoscaling pressure.

#### Scenario: Ranker inference HPA is rendered

- **GIVEN** ranker inference HPA is enabled
- **WHEN** the chart renders the ranker inference HPA
- **THEN** it includes `ranker-inference:throughput`
- **AND** it includes `ranker-inference:task`
- **AND** it does not use `ranker-inference:inference` as the pod-specific
  metric.

#### Scenario: Ranker inference task config is rendered

- **GIVEN** ranker inference is enabled
- **WHEN** the chart renders `config.yaml`
- **THEN** `metrics.task` includes `ranker-inference`
- **AND** its target is `inference_queue`
- **AND** its threshold defaults to `10`
- **AND** `metrics.inference` does not include `ranker-inference`.

#### Scenario: Published chart mirror stays aligned

- **WHEN** the ranker inference HPA and config templates are compared
- **THEN** `src/groundx` and `helm` contain the same queue back-pressure
  contract.

### Requirement: Other Ranker Surfaces Stay Unchanged

This change SHALL NOT modify ranker API HPA behavior, ranker application code,
node provisioning, secrets, search behavior, ranking behavior, or stateful
resources.

#### Scenario: The implementation diff is reviewed

- **WHEN** the implementation diff is reviewed
- **THEN** there is no ranker API capacity metric change
- **AND** there is no ai-server or cashbot-go production algorithm change
- **AND** deployment still requires explicit approval.
