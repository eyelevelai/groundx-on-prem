## 1. Subchart Kafka/KafkaNodePool → Strimzi v1 shape (thin vertical slice — the subchart alone becomes installable against latest Strimzi, independent of the main-chart change in group 2)

- [x] 1.1 `templates/cluster.yaml`: move the `Kafka` CR to `apiVersion: kafka.strimzi.io/v1`; remove `spec.kafka.replicas` and the whole `spec.kafka.storage` block; render `spec.kafka.version`/`spec.kafka.metadataVersion` only when `.Values.cluster.version`/`.Values.cluster.metaVersion` are set; move `metadata.namespace` from `.Values.namespace` to `.Release.Namespace`
  check: helm unittest -f 'tests/cluster_test.yaml' src/groundx/prereqs/kafka-cluster
- [x] 1.2 `templates/cluster.yaml`: add the replication-factor guard — `fail` the render when `.Values.cluster.replicas` is greater than `.Values.nodepool.replicas` (design.md decision 5), naming both keys in the error message
  check: helm unittest -f 'tests/cluster_test.yaml' src/groundx/prereqs/kafka-cluster
- [x] 1.3 `templates/nodepool.yaml`: move the `KafkaNodePool` CR to `apiVersion: kafka.strimzi.io/v1`; move `metadata.namespace` from `.Values.namespace` to `.Release.Namespace`
  check: helm unittest -f 'tests/nodepool_test.yaml' src/groundx/prereqs/kafka-cluster
- [x] 1.4 `values.yaml`: remove the now-dead `cluster.storage` and `namespace` keys (both unused once 1.1/1.3 land); keep `cluster.version`/`cluster.metaVersion` present but unset, with a one-line usage note (design.md decision 3) and a one-line reminder that `cluster.replicas` must not exceed `nodepool.replicas` (design.md decision 5)
  check: helm unittest -f 'tests/cluster_test.yaml' src/groundx/prereqs/kafka-cluster && helm unittest -f 'tests/nodepool_test.yaml' src/groundx/prereqs/kafka-cluster
- [x] 1.5 Wire the subchart's new `tests/` suite into the umbrella gate: add `helm unittest src/groundx/prereqs/kafka-cluster` to `.build/bin/validate-helm.sh` (next to the existing `helm unittest src/groundx` line) so the CI-enforced gate (`helm-tests.yml` → `.build/bin/validate-helm.sh`) actually runs it
  check: grep -q 'helm unittest src/groundx/prereqs/kafka-cluster' .build/bin/validate-helm.sh

## 2. Main-chart KafkaTopic → v1 (namespace unchanged, stays paired with the subchart's release-namespace install per design.md decision 4)

- [x] 2.1 `templates/services/stream-topics.yaml`: move the `KafkaTopic` CR to `apiVersion: kafka.strimzi.io/v1` only — `metadata.namespace` stays on `{{ include "groundx.ns" $ | quote }}`, unchanged
  check: helm unittest -f 'tests/stream_test.yaml' src/groundx
- [x] 2.2 Re-baseline `tests/__snapshot__/stream_test.yaml.snap` for the `KafkaTopic` `apiVersion` change (`helm unittest -u src/groundx`, per AGENTS.md's documented regen command — never hand-edit the `.snap` file)
  check: n/a — generated golden file (Invariant-first: derivable values are never hand-typed); the underlying behavior is already proven by task 2.1's explicit assertions, and the re-baselined snapshot's correctness is confirmed by the full `stream_test.yaml` suite at apply-time verify

## 3. Mirror into `helm/` (manual sync — this repo has no regen tooling between `src/groundx/` and `helm/`, AGENTS.md)

- [x] 3.1 Mirror the group-1 edits (`cluster.yaml`, `nodepool.yaml`, `values.yaml`) into `helm/prereqs/kafka-cluster/`
  check: grep -qx 'apiVersion: kafka.strimzi.io/v1' helm/prereqs/kafka-cluster/templates/cluster.yaml && grep -qx 'apiVersion: kafka.strimzi.io/v1' helm/prereqs/kafka-cluster/templates/nodepool.yaml && ! grep -q '^namespace: eyelevel$' helm/prereqs/kafka-cluster/values.yaml
- [x] 3.2 Mirror the group-2 edit (`stream-topics.yaml`) into `helm/templates/services/stream-topics.yaml`
  check: grep -qx 'apiVersion: kafka.strimzi.io/v1' helm/templates/services/stream-topics.yaml

## 4. Documentation + subchart version bump

- [x] 4.1 Write `src/groundx/prereqs/kafka-cluster/README.md` (new file — none exists today) documenting the namespace-pairing constraint from design.md decision 4/6: a subchart `helm install -n <ns>` must equal the main chart's `.Values.namespace`, or the `KafkaTopic`/bootstrap-service namespaces desync and the `stream-cluster-kafka-bootstrap.<ns>.svc` DNS the main chart depends on breaks; mirror the same file to `helm/prereqs/kafka-cluster/README.md`
  check: n/a — documentation only, no runtime behavior
- [x] 4.2 Add a one-line note next to the existing `stream:` block in `src/groundx/values.yaml` (and its `helm/` mirror) cross-referencing the README's namespace-pairing constraint, matching this file's existing commented-example style (e.g. the `existing:` block a few lines above)
  check: n/a — documentation only, no runtime behavior
- [x] 4.3 Bump `src/groundx/prereqs/kafka-cluster/Chart.yaml` `version` from `0.1.1` to `0.2.0` (design.md decision 7) and mirror to `helm/prereqs/kafka-cluster/Chart.yaml`
  check: grep -qx 'version: 0.2.0' src/groundx/prereqs/kafka-cluster/Chart.yaml && grep -qx 'version: 0.2.0' helm/prereqs/kafka-cluster/Chart.yaml

## 5. Live-Strimzi `kind` CI integration job

- [x] 5.1 Add `.github/workflows/kafka-strimzi-kind.yml`: on `pull_request` and `release` only (not every push — keeps the existing fast `helm-tests.yml` unit-test gate fast), stand up a `kind` cluster, install the latest unpinned Strimzi operator, install both `src/groundx/prereqs/kafka-cluster` and the main chart's stream resources into a non-`eyelevel` namespace, and assert the `Kafka` custom resource and all 5 `KafkaTopic` custom resources reach `Ready`; the job fails (does not skip) when `kind`/Docker is unavailable
  check: test -f .github/workflows/kafka-strimzi-kind.yml && grep -qE '^  (pull_request|release):' .github/workflows/kafka-strimzi-kind.yml && grep -q 'kafka.strimzi.io' .github/workflows/kafka-strimzi-kind.yml

---

Cross-repo coordination (not this service's tasks — see the workspace's
`openspec/changes/gx-25-groundx-strimzi-kafka-cluster-mode-2-bundled-kafka-install/` for the
`groundx-studio-harness` doc-reference update and its publish-gated merge hold): the
`groundx-strimzi-kafka-cluster` subchart version bumped in task 4.3 is consumed by
`groundx-studio-harness`'s two chart-version references; that repo's own PR does not merge until
this chart's `0.2.0` is actually published to `registry.groundx.ai/helm` via the manual,
maintainer-only, PRIVILEGED `src/build.sh` — this pipeline never runs `src/build.sh`.
