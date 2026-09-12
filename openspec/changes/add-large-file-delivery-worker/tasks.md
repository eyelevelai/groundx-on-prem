Evidence: [Implementation and local checks](implementation-evidence.md). Live capacity and activation remain pending.

- [x] Use `largeFileDeliver`, `stream.topics.largeFile`, `queues.largeFile`, and the large-file helper/image names consistently with cashbot-go before activation. Preserve disabled chart output and existing delivery behavior.

## 1. Lock the shared contract
- [x] 1.1 Read the implemented cashbot-go `route-large-files-before-preprocess` config, server entrypoint, helper packaging and resource record. Record the required image and exact YAML bindings; do not enable accounts with an incomplete producer/consumer build.

## 2. Optional worker and transport
- [x] 2.1 Add the disabled-by-default largeFileDeliver values/schema and service helpers, register it in the Go service list, and use the existing generic deployment rendering.
- [x] 2.2 Add the optional large-file topic and Go producer/consumer config. Follow existing Kafka/external-queue overrides and credential references, without adding secret values to ConfigMaps.
- [x] 2.3 Mirror the changed chart sources to helm/ without hand-authoring divergent templates.

## 3. Verification
- [x] 3.1 Add Helm tests proving absent and explicitly disabled settings preserve the current manifests, while enabled Kafka creates the worker and delivery topic and emits matching config. Cover externally managed SQS without an unwanted Kafka topic.
- [x] 3.2 Check enabled credential references and resource limits, schema rejection of invalid settings, and Go decoding of the emitted config against the dependent cashbot-go build.
- [x] 3.3 Run .build/bin/validate-helm.sh for the required OCR fixture, lint, unit tests and dual-surface render checks, plus minikube and mirror comparisons. Regenerate changed snapshots through helm unittest -u only when a reviewed behavior requires them.
- [x] 3.4 Document image/config readiness, measured capacity, secret provisioning and drain-before-removal requirements. Leave deployment and account activation to the separately authorized cashbot-go activation record.
