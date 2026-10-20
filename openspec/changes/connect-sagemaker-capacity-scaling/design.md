## Scope

Owner: opt-in metrics config/schema, source and published mirror.

## Decisions

Reuse existing throughput entries and Redis token lifecycle. Resolve actual serving capacity for explicit SageMaker targets; never count CPU workers or desired future GPUs. Publish fresh pressure to GroundX/SageMaker with EndpointName and VariantName. AWS native target tracking combines this early signal with qualified ConcurrentRequestsPerModel. Missing data stays unknown. One configured metrics owner publishes each target. Standard serving and service-selected provider behavior remain unchanged.

## Validation and rollback

Preserve local HPA and default renders. Test one-to-two-instance capacity, units, stale/error cases, mixed callers and safe native scale-in. Start with scale-in disabled. Suspend the exact target before rollback, retain current serving capacity and requests, then disable metrics publication/configuration.

## Coordination

The ADP coordinating change connect-sagemaker-capacity-scaling contains the cross-repository design, source pins, finite-test scope and evidence requirements. Owning implementations remain in Cashbot, GroundX on-prem and production infrastructure. No customer route is changed by publishing code.
