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

**Preconditions: confirm all three BEFORE step 1. If any fails, stop; do not start the operator
upgrade or the chart upgrade.**

- **Namespaces match.** A 0.1.x install stored its `Kafka`/`KafkaNodePool` CRs in `.Values.namespace`
  (default `eyelevel`), independent of the namespace the Helm release itself was installed into.
  Since 0.2.0 the CRs render into `.Release.Namespace`, so an in-place `helm upgrade` preserves the
  running cluster only when the release's own namespace already equals the namespace the CRs run in.
  Check both:

  ```bash
  # namespace the Helm release lives in
  helm list -A -f '^groundx-kafka-cluster$' -o json | jq -r '.[0].namespace'
  # namespace(s) the running Kafka CR lives in
  kubectl get kafka.kafka.strimzi.io -A \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}'
  ```

  If they are the **same**, use that namespace for the `helm upgrade` in step 4 (the v1 CRs render
  into the same namespace and the upgrade is in place; this is the path the migration CI leg
  exercises). If they **differ**, STOP: a plain `helm upgrade` cannot both find the release (stored
  in its own namespace) and keep the CRs where they run. That case needs an explicit, separately
  planned release adoption (bring the release under the CR namespace before upgrading, for example
  with `helm upgrade --install -n <cr-namespace> --take-ownership`), validated on a copy first. Do
  not use this in-place runbook when the namespaces differ.
- **`cluster.replicas <= nodepool.replicas`.** The subchart's render-time guard rejects the upgrade
  outright otherwise, so confirm it now rather than discovering it mid-upgrade.
- **Version pin ready.** Pin `cluster.version` and `cluster.metaVersion` to the currently-running
  Kafka version, and keep them pinned across the whole hop (steps 1 through 4). Left unset, an
  operator upgrade can roll the running cluster to a newer default version on reconcile.

Then run the ordered procedure:

1. **Upgrade the Strimzi operator in place to `0.50.1`.** Strimzi 0.49 through 0.51 serve **both**
   `kafka.strimzi.io/v1beta2` and `kafka.strimzi.io/v1` at once (v1beta2 is removed in 1.0.0 /
   0.52.0), so any of them can bridge a `v1beta2`-only operator to a `v1`-only one. Use `0.50.1`
   specifically: it ships Apache Kafka `4.0.0` through `4.1.1`, so it still supports `4.0.0` and can
   carry across the hop whatever Kafka version the existing cluster is pinned to. `0.51.0` drops
   Kafka `4.0.0` (the version an operator-`0.47.0`-era 0.1.x install runs), so upgrading straight to
   it would reject such a cluster. Do not upgrade straight to a `v1`-only operator release from a
   `v1beta2`-only one.

   Run the upgrade with an **explicit** command and do not use `helm upgrade --reuse-values`. `0.50.1`
   adds a new `operatorNetworkPolicy` value the older operator chart lacks, so `--reuse-values` keeps
   the old chart's defaults, fails at render (`nil pointer evaluating interface {}.enabled` on
   `operatorNetworkPolicy.enabled`), and applies nothing. It is safe (nothing changes) but the
   operator never upgrades. Re-supply the values instead, reusing the existing operator release name:

   ```bash
   helm upgrade <operator-release> oci://quay.io/strimzi-helm/strimzi-kafka-operator \
     --version 0.50.1 -n <namespace> \
     --set replicas=1 --set nodeSelector.node=eyelevel-cpu-only \
     --wait
   ```

   To carry other custom operator values without re-listing them: on Helm `3.14+`, pass
   `--reset-then-reuse-values` (credential-safe, nothing written to disk; it picks up the new chart's
   defaults, including `operatorNetworkPolicy`). On the supported older clients (Helm `3.8`-`3.13`),
   export and re-apply your values through a private temporary file and delete it afterward, because
   the export can contain secrets (for example a token in `extraEnvs`):

   ```bash
   umask 077; f=$(mktemp)
   helm get values <operator-release> -n <namespace> -o yaml > "$f"
   helm upgrade <operator-release> oci://quay.io/strimzi-helm/strimzi-kafka-operator \
     --version 0.50.1 -n <namespace> -f "$f" --wait
   rm -f "$f"
   ```

   Re-applying your overrides this way still lets new keys like `operatorNetworkPolicy` take the new
   chart's default. Do not use `--reuse-values` (it keeps the old chart's defaults and fails on
   `0.50.1`).
2. **Apply the new Strimzi CRDs.** `helm upgrade` of the operator does **not** upgrade CRDs, so
   after step 1 the cluster's Strimzi CRDs still serve only `v1beta2`. Apply the operator release's
   CRD bundle so every Strimzi CRD serves both `v1beta2` and `v1`
   (`kubectl apply --server-side --force-conflicts -f https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.50.1/strimzi-crds-0.50.1.yaml`).
   The conversion tool in the next step refuses to run until every CRD offers both versions.
3. **Convert the custom resources to `v1`, then upgrade the CRD stored version, using Strimzi's
   `strimzi-v1-api-conversion` tool while the `0.50.1` operator from step 1 is still running.** The
   tool converts every Strimzi custom resource in place (`Kafka`, `KafkaNodePool`, `KafkaTopic`, and
   the `StrimziPodSet`), then makes `v1` the stored CRD version. **CRDs are converted, never deleted
   and recreated:** deleting a Strimzi CRD deletes the objects Kubernetes tracks under it and
   destroys the running cluster's control-plane object, so never substitute a manual `kubectl
   delete` + `kubectl apply` of the CRD for the tool. The tool ships inside the operator image; run
   it as short pods (replace `<namespace>` with the release namespace; on an air-gapped install use
   the `cgr.dev/eyelevel.ai/strimzi-kafka-operator:v0.50.1` image in place of the `quay.io` one).

   **Before converting, complete Strimzi's documented prerequisites:** back up every Strimzi custom
   resource in the cluster (step 1 below), and review the
   [v1 API field changes](https://strimzi.io/docs/operators/0.50.1/deploying#assembly-api-conversion-tool-str)
   for any deprecated or unsupported field that needs a manual edit before conversion.

   **`crd-upgrade` acts cluster-wide:** it removes the `v1beta2` stored API from the shared Strimzi
   CRDs, so every Strimzi custom resource in the cluster must already be converted, not only the
   ones in this release's namespace. `convert-resource --all-namespaces` does that. Run `crd-upgrade`
   only after confirming every resource converted successfully, and if the cluster runs other
   Strimzi workloads you do not own, coordinate before finalizing the shared CRDs. The RBAC below is
   Strimzi's official `0.50.1` conversion-job manifest: scoped to the Strimzi CRDs by name, with the
   `configmaps` access the tool needs to convert `KafkaBridge` metrics configuration.

   ```bash
   # RBAC the conversion tool needs — Strimzi's official 0.50.1 conversion-job permissions
   kubectl apply -f - <<'EOF'
   apiVersion: v1
   kind: ServiceAccount
   metadata: { name: strimzi-v1-api-conversion, namespace: <namespace> }
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata: { name: strimzi-v1-api-conversion }
   rules:
     - apiGroups: [kafka.strimzi.io]
       resources: [kafkas, kafkanodepools, kafkaconnects, kafkaconnectors, kafkabridges, kafkamirrormaker2s, kafkarebalances, kafkatopics, kafkausers]
       verbs: [get, list, patch, update]
     - apiGroups: [core.strimzi.io]
       resources: [strimzipodsets]
       verbs: [get, list, patch, update]
     - apiGroups: [apiextensions.k8s.io]
       resources: [customresourcedefinitions, customresourcedefinitions/status]
       resourceNames:
         - kafkabridges.kafka.strimzi.io
         - kafkaconnectors.kafka.strimzi.io
         - kafkaconnects.kafka.strimzi.io
         - kafkamirrormaker2s.kafka.strimzi.io
         - kafkanodepools.kafka.strimzi.io
         - kafkarebalances.kafka.strimzi.io
         - kafkas.kafka.strimzi.io
         - kafkatopics.kafka.strimzi.io
         - kafkausers.kafka.strimzi.io
         - strimzipodsets.core.strimzi.io
       verbs: [get, list, patch, update]
     - apiGroups: [""]           # configmaps: required when converting KafkaBridge metrics config
       resources: [configmaps]
       verbs: [get, list, create, patch, update]
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRoleBinding
   metadata: { name: strimzi-v1-api-conversion }
   roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: strimzi-v1-api-conversion }
   subjects:
     - { kind: ServiceAccount, name: strimzi-v1-api-conversion, namespace: <namespace> }
   EOF

   # 1) back up every Strimzi custom resource in the cluster before touching anything
   kubectl get kafkas,kafkanodepools,kafkatopics,kafkausers,kafkaconnects,kafkaconnectors,kafkabridges,kafkamirrormaker2s,kafkarebalances -A -o yaml > strimzi-cr-backup.yaml
   kubectl get strimzipodsets.core.strimzi.io -A -o yaml > strimzi-podset-backup.yaml

   # 2) convert EVERY Strimzi custom resource in the cluster to v1 (all namespaces). --attach prints
   #    the tool output; it converts every resource or exits non-zero. Do not proceed on a failure.
   kubectl run strimzi-convert -n <namespace> --restart=Never --attach --rm \
     --image=quay.io/strimzi/operator:0.50.1 \
     --overrides='{"spec":{"serviceAccountName":"strimzi-v1-api-conversion"}}' \
     --command -- /opt/v1-api-conversion/bin/v1-api-conversion.sh convert-resource --all-namespaces

   # 3) make v1 the stored CRD version (cluster-wide) — ONLY after the convert step above succeeded
   kubectl run strimzi-crd-upgrade -n <namespace> --restart=Never --attach --rm \
     --image=quay.io/strimzi/operator:0.50.1 \
     --overrides='{"spec":{"serviceAccountName":"strimzi-v1-api-conversion"}}' \
     --command -- /opt/v1-api-conversion/bin/v1-api-conversion.sh crd-upgrade

   # 4) verify every Strimzi CRD now stores ONLY v1 (each line must print ["v1"])
   kubectl get crd -o name | grep kafka.strimzi.io | while read -r crd; do
     echo -n "$crd  "; kubectl get "$crd" -o jsonpath='{.status.storedVersions}{"\n"}'
   done

   # 5) remove the temporary cluster-wide conversion RBAC (run whether or not the steps above
   #    succeeded, so the privileged binding never lingers)
   kubectl delete clusterrolebinding strimzi-v1-api-conversion --ignore-not-found
   kubectl delete clusterrole strimzi-v1-api-conversion --ignore-not-found
   kubectl delete serviceaccount strimzi-v1-api-conversion -n <namespace> --ignore-not-found
   ```
4. **Only then run `helm upgrade` to chart `0.2.7`** (the `v1`-only template shape). Running the
   `helm upgrade` before steps 1 through 3 complete points the still-`v1beta2`-serving operator at
   CRs the `0.2.7` chart renders as `v1`, which the pre-migration operator cannot reconcile. Apply
   the `cluster.version`/`cluster.metaVersion` pin from the Preconditions here, and use the
   namespace the Preconditions confirmed.

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
