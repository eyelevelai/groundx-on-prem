## Why

Post-processing needs an explicit optional deployment boundary. The chart currently supplies FileProcess but no separate post transport or consumer.

## What Changes

Add default-disabled postProcess worker support and stream.topics.postProcess using existing Kafka/SQS conventions. Propagate queue and worker settings to generated Go YAML for all producers/consumers. Replace implicit FileProcess post support with explicit opt-in support; preserve ordinary ingestion when absent.

## Capabilities

### New Capabilities

- `optional-postprocessing-deployment`: Optional post consumer, stream and generated configuration.

### Modified Capabilities

None.

## Impact

Cashbot supplies compatible optional config and the thin shared post consumer. Chart source, strict schema, workload/topic helpers and shipping mirror change together. Enabled installations incur a worker and topic/external queue; disabled installations incur neither. Existing shared-queue post installations require migration. Companion owner: Cashbot retry-failed-deliveries.
