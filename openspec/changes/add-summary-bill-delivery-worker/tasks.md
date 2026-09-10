## 1. Lock the shared contract
- [ ] 1.1 Read the implemented cashbot-go `route-summary-bills-before-preprocess` config, server entrypoint, helper packaging and resource record. Record the required image and exact YAML bindings; do not enable accounts with an incomplete producer/consumer build.

## 2. Optional worker and transport
- [ ] 2.1 Add the disabled-by-default summaryBillDeliver values/schema and service helpers, register it in the Go service list, and use the existing generic deployment rendering.
- [ ] 2.2 Add the optional file-summary-bill topic and Go producer/consumer config. Follow existing Kafka/external-queue overrides and credential references, without adding secret values to ConfigMaps.
- [ ] 2.3 Mirror the changed chart sources to helm/ without hand-authoring divergent templates.

## 3. Verification
- [ ] 3.1 Add Helm tests proving absent and explicitly disabled settings preserve the current manifests, while enabled Kafka creates the worker and delivery topic and emits matching config. Cover externally managed SQS without an unwanted Kafka topic.
- [ ] 3.2 Check enabled credential references and resource limits, schema rejection of invalid settings, and Go decoding of the emitted config against the dependent cashbot-go build.
- [ ] 3.3 Run helm unittest src/groundx, helm lint src/groundx, helm template src/groundx -f src/groundx/values/minikube/values.yaml, and mirror comparison. Regenerate changed snapshots through helm unittest -u only when a reviewed behavior requires them.
- [ ] 3.4 Document image/config readiness, measured capacity, secret provisioning and drain-before-removal requirements. Leave deployment and account activation to the separately authorized cashbot-go activation record.
