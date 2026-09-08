## Why

Mode 2 (bundled, in-cluster Kafka) cannot be installed end to end against a current, unpinned
Strimzi operator. GX-4 Phase 2 clean-room validation on a fresh EKS cluster hit three separate
incompatibilities between the `groundx-strimzi-kafka-cluster` 0.1.1 subchart and Strimzi's latest
release (1.2.0): the Kafka/KafkaNodePool CRs are emitted on the retired `kafka.strimzi.io/v1beta2`
API (latest Strimzi serves `v1` only); the chart's default `cluster.version: 4.1.1` /
`cluster.metaVersion: 4.1` is a Kafka version no current Strimzi release supports; and the chart
hardcodes `namespace: eyelevel` regardless of the release namespace Helm was given, which both
breaks non-`eyelevel` installs and can desync the KafkaTopic/bootstrap-service namespace pairing
the main chart depends on. Mode 1 (external Kafka) and Mode 3 (SQS) are unaffected. Fixing this now
unblocks bundled-Kafka installs on any current Strimzi release, which is the harness-documented,
no-prior-knowledge install path for Mode 2.

## What Changes

- Move the subchart's `Kafka` and `KafkaNodePool` custom resources
  (`src/groundx/prereqs/kafka-cluster/templates/`) from `kafka.strimzi.io/v1beta2` to
  `kafka.strimzi.io/v1`.
- Move the main chart's `KafkaTopic` (`src/groundx/templates/services/stream-topics.yaml`) to
  `kafka.strimzi.io/v1` only — its namespace (`groundx.ns` / `.Values.namespace`) is **unchanged**.
- **BREAKING** (subchart CR shape): remove `spec.kafka.replicas` and `spec.kafka.storage` from the
  Kafka CR — Strimzi `v1` requires broker replica count and storage to live on the
  `KafkaNodePool` only. An existing `v1beta2` Kafka CR with these fields set is invalid under `v1`.
- Make `spec.kafka.version` and `spec.kafka.metadataVersion` optional passthroughs, rendered only
  when `.Values.cluster.version` / `.Values.cluster.metaVersion` are set. Both are unset by
  default, so a fresh install lets Strimzi choose its own supported defaults instead of pinning a
  version the installed operator may reject.
- Change the **subchart's** Kafka/KafkaNodePool namespace from the hardcoded `eyelevel` literal to
  `.Release.Namespace`, so `helm install -n <ns>` places the cluster in the namespace the operator
  actually asked for. The main chart's namespace behavior (`.Values.namespace`, default
  `eyelevel`) is untouched.
- In the subchart's `values.yaml`: keep `cluster.replicas` (drives the in-cluster replication-factor
  config), remove the now-dead `cluster.storage` key (Kafka `v1` storage sizing lives on
  `nodepool.storage`, already 5Gi), and make `cluster.version`/`cluster.metaVersion` optional/unset.
- Bump `src/groundx/prereqs/kafka-cluster/Chart.yaml` version from `0.1.1` — this is the version
  string the harness install docs reference for the subchart.
- Re-baseline `src/groundx/tests/__snapshot__/stream_test.yaml.snap` for the `KafkaTopic` API-version
  change, and add a new helm-unittest suite for the subchart (`cluster.yaml`/`nodepool.yaml`)
  asserting: `v1` API, no `replicas`/`storage` on the Kafka CR, 5Gi PVC size sourced from
  `nodepool.storage`, release-namespace placement, and that the KafkaTopic and the Kafka
  bootstrap service resolve to the same namespace.
- Mirror every `src/groundx/prereqs/kafka-cluster/` and `stream-topics.yaml` edit into the
  published `helm/` mirror (manual sync per this repo's existing convention — no regen tooling
  exists).
- Add a live-Strimzi `kind` CI integration job that installs the latest unpinned Strimzi operator
  plus both charts into a non-`eyelevel` namespace and asserts the Kafka CR and all KafkaTopics
  reach `Ready`; the job fails (does not skip) if `kind`/Docker is unavailable, and runs on
  `pull_request` and `release` only (not every push, to keep the fast unit-test gate fast).
- Document, in this repo, that a subchart install's `-n <namespace>` must equal the main chart's
  `.Values.namespace` — otherwise the KafkaTopic (main chart, `groundx.ns`) and the Kafka bootstrap
  service (subchart, now `.Release.Namespace`) land in different namespaces and the
  `stream-cluster-kafka-bootstrap.<ns>.svc` DNS the main chart expects breaks.

Out of scope: the air-gapped/Chainguard Strimzi image seeds (`values.strimzi.operator.yaml`,
`values.strimzi.cluster.yaml`) are deferred — the private image mirror does not yet carry a
`v1`-serving Strimzi image, so air-gapped Mode 2 stays on its current pinned recipe until that
lands separately. The companion harness-docs update (subchart version references in
`groundx-studio-harness`) is a separate repo and a separate PR, sequenced after this chart's
release ships.

**Blast radius:** Mode 2 (bundled Kafka) installs only — any environment that deploys the
`groundx-strimzi-kafka-cluster` subchart against a live or future Strimzi operator install. Mode 1
(external Kafka, `stream.existing`) and Mode 3 (SQS) render no Kafka/KafkaNodePool/KafkaTopic
resources from this path and are unaffected. No currently-running Mode 2 environment is known to
exist on the old `v1beta2` shape from this workspace's own deployments (GX-4's validation cluster
was ephemeral and has been torn down); a customer or field install already running the old shape
against a `v1beta2`-serving Strimzi (≤0.47.0) would need to upgrade Strimzi and re-apply the new CR
shape together, since `v1beta2` and `v1` are not both servable by one Strimzi install. **Rollback:**
this is a chart-template-only change (no data-plane migration) — reverting to the prior chart/subchart
version and the prior Strimzi operator version restores the old behavior; there is no persisted
state this change reshapes (Kafka topic data is unaffected by the CR's API version or namespace
field). **Roll-forward:** a customer already running a working `v1beta2` install should pin their
Strimzi operator until they are ready to upgrade it and the subchart together, matching the CR
`apiVersion` to the operator's served version.

No open design questions remain — the fix direction, the specific API/namespace/version changes,
and the namespace-parity constraint are confirmed by Ben Fletcher's review comment and validated
empirically by this session's spike (Strimzi 1.2.0 serving `v1` only; a `v1` Kafka CR with
`replicas`/`storage` removed and versions unset defaulting to a supported Kafka/metadata version;
`.Release.Namespace` plus all 5 KafkaTopics reconciling correctly in a non-`eyelevel` namespace).

## Capabilities

### New Capabilities
- `strimzi-kafka-v1-compat`: the bundled (Mode 2) Kafka deployment's Strimzi API compatibility —
  the Kafka/KafkaNodePool/KafkaTopic custom resources render on `kafka.strimzi.io/v1`, the Kafka CR
  carries no node-count or storage fields (those live on KafkaNodePool only), the Kafka
  version/metadata-version are optional and unset by default, and the subchart's Kafka resources
  land in the Helm release namespace rather than a hardcoded one.

### Modified Capabilities
(none — no existing `openspec/specs/` capability currently covers Kafka/Strimzi resource rendering)

## Impact

- **Code:** `src/groundx/prereqs/kafka-cluster/{Chart.yaml,values.yaml,templates/cluster.yaml,templates/nodepool.yaml}`;
  `src/groundx/templates/services/stream-topics.yaml`; mirrored into
  `helm/prereqs/kafka-cluster/{Chart.yaml,values.yaml,templates/cluster.yaml,templates/nodepool.yaml}`
  and `helm/templates/services/stream-topics.yaml`.
- **Tests:** `src/groundx/tests/__snapshot__/stream_test.yaml.snap` (re-baselined), a new
  helm-unittest suite for the subchart, `.github/workflows/helm-tests.yml`-adjacent new `kind`
  integration workflow.
- **Dependencies:** none in-repo; external dependency is the Strimzi operator version installed
  alongside these charts (documented, not pinned by this change).
- **Docs:** this repo's own docs note the subchart-namespace-must-equal-main-chart-namespace
  constraint. The `groundx-studio-harness` doc updates (subchart version references) are a separate
  repo's change, out of scope here.
- **No API/schema contract change** to `src/groundx/values.schema.json` beyond the removal of the
  now-dead `cluster.storage` key from the **subchart's own** `values.yaml` (the subchart has no
  `values.schema.json` of its own today; the main chart's schema is untouched since this subchart is
  installed standalone, not as a chart dependency of `groundx`).
