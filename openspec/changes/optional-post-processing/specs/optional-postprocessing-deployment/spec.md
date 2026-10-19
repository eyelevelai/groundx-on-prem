## ADDED Requirements

### Requirement: optional-postprocessing-deployment

The chart SHALL default post-processing to unsupported. Enabled support SHALL render a consumer and matching queues.filePostProcess/postProcessFileServer config using existing Kafka/SQS conventions. No FileProcess fallback SHALL exist.

#### Scenario: Disabled support
- **WHEN** support is absent or explicitly disabled
- **THEN** no post worker, topic, queue/server config or post credential binding is rendered, and ordinary ingestion remains supported.

#### Scenario: Enabled transport
- **WHEN** post support is enabled with valid Kafka or external SQS settings
- **THEN** producers and consumer receive matching generated Go config and the configured consumer is rendered
- **AND** Kafka mode registers its topic while SQS mode adds no Kafka topic for post-processing.

#### Scenario: Incomplete transport
- **WHEN** enabled settings lack required transport or worker fields
- **THEN** schema/render/config validation fails before activation.
