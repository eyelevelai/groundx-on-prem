## Why

Standard SageMaker serving is not connected to GroundX capacity metrics or early GPU warm-up. Kubernetes HPA cannot resize SageMaker variants.

## What Changes

Implement opt-in metrics config/schema, source and published mirror. Reuse the existing GroundX throughput calculation and AWS Application Auto Scaling. Keep direct inference clients, queues, deadlines, retry policy and original serving image. No new limiter or scaling framework.

## Capabilities

### New Capabilities

- `sagemaker-capacity-scaling`: opt-in capacity reporting and native scaling.

## Impact

Existing releases are unchanged without explicit opt-in. No stateful data changes. Isolated finite validation uses one to two GPUs under the cumulative USD3000 cap. Production activation requires exact deployment/readback and rollout identity; rollback disables scaling/publication while preserving active requests.
