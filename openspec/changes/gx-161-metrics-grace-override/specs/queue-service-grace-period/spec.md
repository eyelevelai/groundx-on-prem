## ADDED Requirements

### Requirement: Metrics grace overrides accept an omitted replica count

The chart SHALL accept `metrics.replicas.gracePeriod` when `metrics.replicas.desired` is absent, including upgrades that reuse values from a release without a Metrics replicas default. The deployment SHALL use one replica when the count is omitted and preserve every explicitly configured count.

#### Scenario: Reused release values omit the Metrics replica count

- **GIVEN** an existing release whose defaults omit `metrics.replicas.desired`
- **WHEN** an upgrade reuses its values and sets `metrics.replicas.gracePeriod=77`
- **THEN** schema validation succeeds, Metrics renders one replica, pod grace is 77 seconds, and `drainSeconds` is 47.

#### Scenario: An explicit replica count accompanies the grace override

- **GIVEN** `metrics.replicas.gracePeriod=77`
- **WHEN** `metrics.replicas.desired` is explicitly zero or three
- **THEN** the deployment renders that count and retains pod grace 77 and drain 47.
