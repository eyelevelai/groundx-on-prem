# groundx-strimzi-kafka-cluster

Standalone Strimzi Kafka subchart for Mode-2 (bundled/in-cluster Kafka) installs. Deploys a
`Kafka` custom resource (KRaft, node-pool mode) and a `KafkaNodePool` on the stable
`kafka.strimzi.io/v1` API, against an unpinned Strimzi operator.

## Namespace pairing (required)

Since 0.2.0, the `Kafka` and `KafkaNodePool` custom resources land in the **Helm release
namespace** (`.Release.Namespace`) rather than a hardcoded namespace — i.e. wherever this
subchart is installed with `helm install ... -n <ns>`.

The **main `groundx` chart's** `KafkaTopic` resources and its `stream-cluster-kafka-bootstrap`
DNS lookup stay keyed on the main chart's `.Values.namespace` (`groundx.ns`), unchanged by this
subchart.

**The two namespaces must be the same value.** If they diverge, the `KafkaTopic` resources and
the `Kafka`/`KafkaNodePool` resources end up in different namespaces, and the main chart's
`stream-cluster-kafka-bootstrap.<namespace>.svc.cluster.local` bootstrap-service DNS lookup
resolves against the wrong (or a nonexistent) namespace — the Kafka connection breaks.

When installing this subchart standalone, always pass `-n <ns>` where `<ns>` equals the main
chart's `.Values.namespace`:

```bash
helm install groundx-kafka-cluster groundx/groundx-strimzi-kafka-cluster --version 0.2.0 \
  -n <ns>
```

## Values

| Key | Default | Notes |
| --- | --- | --- |
| `serviceName` | `stream` | Name prefix for the `Kafka`/`KafkaNodePool` resources. |
| `node` | `eyelevel-cpu-only` | Node-affinity/toleration selector for the Kafka pods. |
| `cluster.port` | `9092` | Internal Kafka listener port. |
| `cluster.replicas` | `1` | Drives the replication-factor config block (`default.replication.factor` etc). Must not exceed `nodepool.replicas` — the render fails otherwise. |
| `cluster.version` | unset | Optional Kafka version passthrough. Leave unset to let Strimzi pick a version it supports; set to pin an explicit version (e.g. for an air-gapped/pinned-image install). |
| `cluster.metaVersion` | unset | Optional Kafka metadata version passthrough, same rule as `cluster.version`. |
| `nodepool.replicas` | `1` | Broker/controller pool size (KRaft dual-role nodes). |
| `nodepool.storage` | `5Gi` | Per-broker persistent volume size. |
