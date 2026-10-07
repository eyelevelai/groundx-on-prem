## ADDED Requirements

### Requirement: Large file delivery is optional
The chart SHALL support an opt-in largeFileDeliver Go worker and its transport configuration. Absent or disabled settings SHALL preserve existing rendered workloads, topics, credentials and Go configuration.

#### Scenario: Existing installation remains unchanged
- **WHEN** the feature is absent or explicitly disabled
- **THEN** no delivery workload, topic or credential binding is added
- **AND** existing manifests and config hashes remain unchanged

### Requirement: Enabled worker and transport agree
The chart SHALL render the enabled worker and producer/consumer configuration matching cashbot-go, with its required image, measured resource settings and server-managed credential references. It SHALL support the existing Kafka and external-queue deployment conventions.

#### Scenario: Kafka delivery is enabled
- **WHEN** largeFileDeliver is enabled with Kafka
- **THEN** the worker deployment and large-file topic are rendered through existing chart mechanisms
- **AND** producer and consumer configuration refer to the same topic

#### Scenario: Existing SQS queue is selected
- **WHEN** delivery uses an externally managed SQS queue
- **THEN** both workers receive that queue configuration
- **AND** no delivery Kafka topic is created

#### Scenario: Credential references remain private
- **WHEN** delivery credentials are configured
- **THEN** the workload binds server-managed secret references
- **AND** no service-account credential material is included in a ConfigMap

### Requirement: Deployment readiness precedes account activation
Kubernetes routing SHALL remain disabled until compatible images, schema, delivery transport, authorized destination and measured budgets are verified. Rollback SHALL retain delivery dependencies until pending work is drained or reconciled.

#### Scenario: Worker is not ready
- **WHEN** the required delivery image or transport is unavailable
- **THEN** no account is enabled for large file routing

#### Scenario: Pending delivery during rollback
- **WHEN** new claims are disabled while delivery or callback finalization is pending
- **THEN** the worker, transport and credential references remain available until that work is drained or reconciled

### Requirement: Chart source and published mirror agree
Changes SHALL originate in src/groundx and be mirrored to helm. Render tests SHALL prove disabled compatibility and enabled resource/config behavior.

#### Scenario: Chart validation
- **WHEN** the source chart and published mirror are rendered for the same settings
- **THEN** their deployment behavior agrees
- **AND** Helm unit tests, lint and the existing minikube render pass
