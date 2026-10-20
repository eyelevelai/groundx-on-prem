## ADDED Requirements

### Requirement: Reuse existing demand calculation and capacity ownership

The metrics service SHALL reuse existing Redis throughput records and its existing throughput calculation for explicitly configured SageMaker targets. It SHALL obtain remote serving capacity from SageMaker, preserve existing local calculations and avoid creating another request limiter, queue, gateway or distributed permit system.

#### Scenario: External capacity differs from CPU capacity
- **GIVEN** two serving SageMaker instances and eight CPU workers
- **WHEN** the external target's throughput pressure is calculated
- **THEN** its capacity denominator uses two remote instances, not eight workers or desired future instances
- **AND** the same work estimate produces half the one-instance pressure
- **AND** unrelated local metrics and Redis records are unchanged.

#### Scenario: Global prewarming is enabled
- **GIVEN** the existing system-wide pending-work estimate includes work not yet assigned to the SageMaker endpoint
- **WHEN** that estimate drives early scaling
- **THEN** it remains labelled a system-wide warm-up hint
- **AND** no endpoint-specific queue depth or immediate free-slot claim is derived from it.

### Requirement: Use native AWS scaling and standard serving

AWS Application Auto Scaling SHALL be the sole writer of automatic SageMaker variant instance count. It SHALL use the existing GroundX demand signal and a qualified native concurrent-request metric. The standard container and existing direct provider paths SHALL remain in use.

#### Scenario: Both request producers load the endpoint
- **GIVEN** Cashbot and Arcadia send requests to the same configured variant
- **WHEN** native concurrency rises above its qualified target
- **THEN** AWS can add instances within the configured maximum
- **AND** no CPU Deployment, application counter or custom scaling loop resizes that variant
- **AND** the streaming metric is verified through the final token, including container waiting.

### Requirement: Telemetry cannot invent idle capacity

The existing metrics process SHALL own one bounded publisher per configured target. It SHALL emit correctly dimensioned fresh observations, report failures and preserve missing data as unknown. It SHALL make no observation or publication calls on the inference path.

#### Scenario: AWS or Redis observation fails
- **GIVEN** a capacity lookup or pending-work read fails, is stale or reports no confirmed serving capacity
- **WHEN** publication is due
- **THEN** the publisher records a visible error and emits no fabricated zero or refreshed old sample
- **AND** requests continue through their existing deadline and retry owners.

#### Scenario: Duplicate publishers are configured
- **GIVEN** two metrics deployments would write the same endpoint/variant series
- **WHEN** deployment configuration is validated
- **THEN** enablement is rejected until one existing deployment owns publication
- **AND** no leader-election service is introduced.

### Requirement: Finite qualification precedes customer activation

Validation SHALL prove actual one-to-two-instance capacity, mixed-caller latency/errors/throughput, telemetry failure behavior and safe scale-in before enabling customer autoscaling. It SHALL preserve original requests, current provider semantics and the cumulative USD 3000 finite-test ceiling. Automatic scale-in SHALL remain disabled until active-stream completion is qualified.

#### Scenario: Scaling is requested but capacity is unavailable
- **GIVEN** AWS accepts a scaling action but cannot provision the additional GPU
- **WHEN** results are reported
- **THEN** only confirmed serving instances count as capacity
- **AND** shortage, latency, errors and cost are reported without a substitution or successful-scaling claim.

#### Scenario: Scale-in interrupts an active stream
- **GIVEN** finite validation detects interruption during native scale-in
- **WHEN** rollout eligibility is evaluated
- **THEN** automatic scale-in remains disabled
- **AND** the limitation remains open without adding a custom drain controller.
