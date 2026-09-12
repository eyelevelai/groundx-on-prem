## Context

Baseline: pushed `origin/main` at `80f55ce7b1ff0491b2e7bc4262d99a20fe49813f`. No active or archived OpenSpec changes exist on that ref; only `openspec/config.yaml` is tracked.

`src/groundx/templates/_helpers/app/golang.tpl` enumerates Go services; `app/golang.yaml` renders each service's settings and reads shared config. `templates/_helpers/services/topics.tpl` enumerates stream topics and Kafka presence. `templates/resources/config-yaml.yaml` emits the Go configuration. Per-service helpers, the strict values schema, and Helm tests complete the deployment contract. `helm/` is the published mirror, not the editable source.

## Decisions

Use the existing Go workload pattern, with `largeFileDeliver.enabled` false unless explicitly enabled. Include the worker, delivery topic and Go config only when enabled. Implement the service's required settings helpers and values/schema together, including its image, resources, replica count, queue configuration and normal health probes. Do not add another generic deployment abstraction or autoscaling mechanism.

Use `large-file` as the default topic, with the existing stream override conventions. Match `LargeFile` and the actual worker server/config fields from cashbot-go; validate the rendered YAML against that Go configuration boundary. Preserve both supported stream modes instead of assuming every installation uses in-cluster Kafka. A Kafka configuration creates or references the topic through the chart's existing topic mechanism; externally managed SQS uses its configured queue and does not create a Kafka topic.

Use the existing secret-reference mechanism for server-managed credentials. Do not place service-account JSON in ConfigMaps, example values, or committed fixtures. The image must include the bounded PDF parser helper needed by the producer; producer counting and consumer upload budgets must match the measured cashbot-go activation record. Image tags, resource limits and credential names are deployment inputs, not guessed defaults for activation.

The disabled render is the compatibility boundary: no new deployment, topic, credential binding, or Go config change that would trigger a rollout. When enabled, expect a worker deployment and transport config, with config-hash rollouts for existing producer pods as needed. Test named rendered resources and decoded configuration, not only template text.

## Rollout and rollback

1. Land compatible cashbot-go schema, producer/consumer binaries and optional-config behavior. Keep all account policies off.
2. Render and validate this chart with disabled and enabled settings. Verify the shipping mirror.
3. With separate operational authorization, deploy a compatible image and measured budgets to a controlled environment, establish the authorized Shared drive credential binding, and verify worker/topic readiness.
4. Enable accounts only after cashbot-go's resource, delivery, completion-semantics and activation gates pass.
5. To roll back, disable new claims first. Keep the delivery worker and its dependencies until pending publication, uploads and finalization are drained or reconciled. Do not delete delivered Drive copies or database receipts.

No live cluster operation is part of local chart validation.
