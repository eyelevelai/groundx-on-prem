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
   specifically: it ships Apache Kafka `4.0.0` through `4.1.1`, so it still supports `4.0.0` and can
   carry across the hop whatever Kafka version the existing cluster is pinned to. `0.51.0` drops
   Kafka `4.0.0` (the version an operator-`0.47.0`-era 0.1.x install runs), so upgrading straight to
   it would reject such a cluster. Do not upgrade straight to a `v1`-only operator release from a
   `v1beta2`-only one.
2. **Apply the new Strimzi CRDs.** `helm upgrade` of the operator does **not** upgrade CRDs, so
   after step 1 the cluster's Strimzi CRDs still serve only `v1beta2`. Apply the operator release's
   CRD bundle so every Strimzi CRD serves both `v1beta2` and `v1`
   (`kubectl apply --server-side --force-conflicts -f https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.50.1/strimzi-crds-0.50.1.yaml`).
   The conversion tool in the next step refuses to run until every CRD offers both versions.
3. **Convert the custom resources to `v1`, then upgrade the CRD stored version, using Strimzi's
   `strimzi-v1-api-conversion` tool while the `0.50.1` operator from step 1 is still running.** The
   tool converts every Strimzi custom resource in place (`Kafka`, `KafkaNodePool`, `KafkaTopic`, and
   the `StrimziPodSet`), then makes `v1` the stored CRD version. **CRDs are converted, never deleted
   and recreated** — deleting a Strimzi CRD deletes the objects Kubernetes tracks under it and
   destroys the running cluster's control-plane object, so never substitute a manual `kubectl
   delete` + `kubectl apply` of the CRD for the tool. The tool ships inside the operator image;
   run it as two short pods (replace `<namespace>` with the release namespace; on an air-gapped
   install use the `cgr.dev/eyelevel.ai/strimzi-kafka-operator:v0.50.1` image in place of the
   `quay.io` one). **`crd-upgrade` acts cluster-wide** — it removes the `v1beta2` stored API from
   the shared Strimzi CRDs, so every Strimzi custom resource in the cluster must be converted first,
   not only the ones in this release's namespace. `convert-resource --all-namespaces` does that; if
   the cluster runs other Strimzi workloads you do not own, coordinate before running `crd-upgrade`.

   ```bash
   # RBAC the conversion tool needs (it reads/patches all Strimzi CRs and the CRDs, cluster-wide)
   kubectl apply -f - <<'EOF'
   apiVersion: v1
   kind: ServiceAccount
   metadata: { name: strimzi-v1-api-conversion, namespace: <namespace> }
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata: { name: strimzi-v1-api-conversion }
   rules:
     - { apiGroups: [kafka.strimzi.io], resources: ["*"], verbs: [get, list, patch, update] }
     - { apiGroups: [core.strimzi.io], resources: ["*"], verbs: [get, list, patch, update] }
     - { apiGroups: [apiextensions.k8s.io], resources: [customresourcedefinitions, customresourcedefinitions/status], verbs: [get, list, patch, update] }
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRoleBinding
   metadata: { name: strimzi-v1-api-conversion }
   roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: strimzi-v1-api-conversion }
   subjects:
     - { kind: ServiceAccount, name: strimzi-v1-api-conversion, namespace: <namespace> }
   EOF

   # 1) convert EVERY Strimzi custom resource in the cluster to v1 (all namespaces), before the
   #    cluster-wide crd-upgrade below finalizes the CRDs
   kubectl run strimzi-convert -n <namespace> --restart=Never --attach --rm \
     --image=quay.io/strimzi/operator:0.50.1 \
     --overrides='{"spec":{"serviceAccountName":"strimzi-v1-api-conversion"}}' \
     --command -- /opt/v1-api-conversion/bin/v1-api-conversion.sh convert-resource --all-namespaces

   # 2) make v1 the stored CRD version (cluster-wide)
   kubectl run strimzi-crd-upgrade -n <namespace> --restart=Never --attach --rm \
     --image=quay.io/strimzi/operator:0.50.1 \
     --overrides='{"spec":{"serviceAccountName":"strimzi-v1-api-conversion"}}' \
     --command -- /opt/v1-api-conversion/bin/v1-api-conversion.sh crd-upgrade

   # 3) remove the temporary cluster-wide conversion RBAC (run whether or not the steps above
   #    succeeded, so the privileged binding never lingers)
   kubectl delete clusterrolebinding strimzi-v1-api-conversion --ignore-not-found
   kubectl delete clusterrole strimzi-v1-api-conversion --ignore-not-found
   kubectl delete serviceaccount strimzi-v1-api-conversion -n <namespace> --ignore-not-found
   ```
4. **Only then run `helm upgrade` to chart `0.2.7`** (the `v1`-only template shape). Running the
   `helm upgrade` before steps 1 through 3 complete points the still-`v1beta2`-serving operator at
   CRs the `0.2.7` chart renders as `v1`, which the pre-migration operator cannot reconcile.
5. **Pin `cluster.version` and `cluster.metaVersion` to the currently-running Kafka version across
   the whole hop** (steps 1 through 4). Left unset, an operator upgrade can roll the running
   cluster to a newer default version on reconcile.
6. **Keep the `helm upgrade` release namespace equal to the old install's `.Values.namespace`
   value.** Since 0.2.0 the `Kafka`/`KafkaNodePool` CRs land in `.Release.Namespace` (see
   "Namespace pairing" above); installing under a different release namespace moves the CRs there,
   orphaning the original running cluster (or creating an unreachable duplicate) rather than
   upgrading it in place.
7. **Before upgrading, confirm `cluster.replicas <= nodepool.replicas`.** The subchart's
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
