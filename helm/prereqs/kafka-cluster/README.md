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
helm install groundx-kafka-cluster groundx/groundx-strimzi-kafka-cluster --version 0.2.7 \
  -n <ns>
```

## Upgrading an existing 0.1.x install

A 0.1.x install predates this chart's move to the stable Strimzi v1 API and the release-namespace
CR placement below. Upgrading in place is **not** a drop-in `helm upgrade` — it requires the
following ordered procedure. Follow the steps in order; skipping the operator stepping-stone or
converting the CRDs out of order can destroy the running cluster's control-plane object.

1. **Upgrade the Strimzi operator in place to `0.50.1`.** Strimzi 0.49 through 0.51 serve **both**
   `kafka.strimzi.io/v1beta2` and `kafka.strimzi.io/v1` at once (v1beta2 is removed in 1.0.0 /
   0.52.0), so any of them can bridge a `v1beta2`-only operator to a `v1`-only one. Use `0.50.1`
   specifically: it is the newest dual-serving release that still supports Apache Kafka `4.0.x`,
   so it can carry the running cluster's pinned Kafka version across the hop. `0.51.0` drops Kafka
   `4.0.x`, so an operator upgrade to it would reject a cluster still pinned to `4.0.x`. Do not
   upgrade straight to a `v1`-only operator release from a `v1beta2`-only one.
2. **Run Strimzi's `strimzi-v1-api-conversion` tool, then the CRD upgrade, against the existing
   `Kafka`/`KafkaNodePool` resources, while the `0.50.1` operator from step 1 is still running.**
   This converts the stored CRD version to `v1` in place. **CRDs are converted, never deleted and
   recreated.** Deleting a Strimzi CRD deletes the `Kafka`/`KafkaNodePool` objects Kubernetes
   tracks under it, which destroys the running cluster's control-plane object (not the topic data
   itself, but the object Strimzi reconciles against) — never run a manual `kubectl delete`
   followed by `kubectl apply` of the CRD as a substitute for the conversion tool.
3. **Only then run `helm upgrade` to chart `0.2.7`** (the `v1`-only template shape). Running the
   `helm upgrade` before steps 1 and 2 complete points the still-`v1beta2`-serving operator at CRs
   the `0.2.7` chart renders as `v1`, which the pre-migration operator cannot reconcile.
4. **Pin `cluster.version` and `cluster.metaVersion` to the currently-running Kafka version across
   the whole hop** (steps 1 through 3). Left unset, an operator upgrade can roll the running
   cluster to a newer default version on reconcile.
5. **Keep the `helm upgrade` release namespace equal to the old install's `.Values.namespace`
   value.** Since 0.2.0 the `Kafka`/`KafkaNodePool` CRs land in `.Release.Namespace` (see
   "Namespace pairing" above); installing under a different release namespace moves the CRs there,
   orphaning the original running cluster (or creating an unreachable duplicate) rather than
   upgrading it in place.
6. **Before upgrading, confirm `cluster.replicas <= nodepool.replicas`.** The subchart's
   render-time guard rejects the upgrade outright if this doesn't already hold, so check it ahead
   of time rather than discovering it mid-upgrade.

A fresh/greenfield install needs none of this — leave `cluster.version`/`cluster.metaVersion` unset
so Strimzi picks a supported default, and the CRs land directly in the release namespace with no
prior state to move.

## Values

| Key | Default | Notes |
| --- | --- | --- |
| `serviceName` | `stream` | Name prefix for the `Kafka`/`KafkaNodePool` resources. |
| `node` | `eyelevel-cpu-only` | Node-affinity/toleration selector for the Kafka pods. |
| `cluster.port` | `9092` | Internal Kafka listener port. |
| `cluster.replicas` | `1` | Drives the replication-factor config block (`default.replication.factor` etc). Must not exceed `nodepool.replicas` — the render fails otherwise. |
| `cluster.version` | unset | Optional Kafka version passthrough. See "Upgrading an existing 0.1.x install" above for when this must be pinned. |
| `cluster.metaVersion` | unset | Optional Kafka metadata version passthrough, same rule as `cluster.version`. |
| `nodepool.replicas` | `1` | Broker/controller pool size (KRaft dual-role nodes). |
| `nodepool.storage` | `5Gi` | Per-broker persistent volume size. |
