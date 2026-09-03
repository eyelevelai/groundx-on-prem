## ADDED Requirements

### Requirement: Strimzi custom resources render on the stable v1 API
All Strimzi custom resources this chart emits — the subchart's `Kafka` and `KafkaNodePool`, and the main chart's `KafkaTopic` — SHALL render with `apiVersion: kafka.strimzi.io/v1`. No resource in this chart SHALL render `kafka.strimzi.io/v1beta2`.

Polarity: accept and enqueue (`v1` is the only accepted shape) / reject the retired `v1beta2` shape outright — a resource on the old API is not a degraded-but-working state, it is a shape Strimzi 1.x refuses to install.

#### Scenario: subchart Kafka and KafkaNodePool CRs render v1
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with default values
- **THEN** the rendered `Kafka` and `KafkaNodePool` manifests both carry
  `apiVersion: kafka.strimzi.io/v1`, and neither renders `kafka.strimzi.io/v1beta2` anywhere in
  the output

#### Scenario: main-chart KafkaTopic CR renders v1
- **WHEN** `helm template` renders `src/groundx` with default values (Mode 2, `stream.existing`
  unset)
- **THEN** every rendered `KafkaTopic` manifest carries `apiVersion: kafka.strimzi.io/v1`, and no
  `KafkaTopic` renders `kafka.strimzi.io/v1beta2`

### Requirement: the live-Strimzi CI job proves reconciliation, not only render shape
The chart's Strimzi-compatibility gate SHALL additionally install the subchart and the main chart's `KafkaTopic` resources against a live, unpinned-latest Strimzi operator in a `kind` cluster and require the `Kafka` custom resource and every `KafkaTopic` custom resource to reach `Ready`, because a rendered-and-snapshot-matched resource is not proof the installed operator will accept it — the prior `v1beta2` chart passed its own `helm-unittest` snapshot gate while failing to install. The job SHALL fail (not skip) when `kind`/Docker is unavailable.

Polarity: this is a gate-class requirement — it must catch the adversarial counterexample below and must not block the legitimate one.

#### Scenario: catches — a stale-API-version or v1-invalid CR that a snapshot test alone would miss
- **WHEN** any Strimzi CR this chart emits renders on `kafka.strimzi.io/v1beta2`, or a `Kafka` CR
  renders with a `spec.kafka.replicas` or `spec.kafka.storage` field present, and the live-Strimzi
  `kind` CI job installs both charts against the latest unpinned Strimzi operator
- **THEN** the job fails — the `Kafka` custom resource does not reach `Ready` (the operator
  rejects or cannot reconcile the resource), and no green result is recorded

#### Scenario: must not block — a correctly-shaped v1 install reaches Ready
- **WHEN** the subchart's `Kafka` and `KafkaNodePool` and the main chart's `KafkaTopic` resources
  all render on `kafka.strimzi.io/v1` with no `spec.kafka.replicas`/`spec.kafka.storage` on the
  `Kafka` CR, and the live-Strimzi `kind` CI job installs both charts against the latest unpinned
  Strimzi operator in a non-`eyelevel` namespace
- **THEN** the `Kafka` custom resource and all 5 `KafkaTopic` custom resources reach `Ready`, and
  the job passes

### Requirement: the Kafka custom resource carries no per-broker replica or storage fields
The subchart's `Kafka` CR template SHALL NOT render `spec.kafka.replicas` or `spec.kafka.storage` under any values combination, because Strimzi `v1` moves broker replica count and storage sizing to the `KafkaNodePool` resource only — a `v1` `Kafka` CR that still sets either field is invalid under `v1`.

Polarity: reject before state — the deprecated fields must be entirely absent from the rendered manifest, not merely unset-with-a-default; broker count and storage come only from `KafkaNodePool.spec.replicas` / `KafkaNodePool.spec.storage.volumes[0].size`.

#### Scenario: Kafka CR omits replicas and storage
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with default values
- **THEN** the rendered `Kafka` manifest's `spec.kafka` block contains no `replicas` key and no
  `storage` key

#### Scenario: broker count and disk size come from the KafkaNodePool only
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with default values
- **THEN** the rendered `KafkaNodePool` manifest's `spec.replicas` equals
  `.Values.nodepool.replicas` and `spec.storage.volumes[0].size` equals `5Gi`
  (`.Values.nodepool.storage`)

### Requirement: Kafka version and metadata version are optional passthroughs
`spec.kafka.version` and `spec.kafka.metadataVersion` SHALL render only when `.Values.cluster.version` / `.Values.cluster.metaVersion` are explicitly set, and SHALL be unset by default so a fresh install lets Strimzi choose its own supported defaults instead of pinning a Kafka version the installed operator may reject.

Polarity: skip the unrelated field when the value is unset (do not render a pinned default); accept and render the literal value verbatim when the operator explicitly sets one.

#### Scenario: default install omits both version fields
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with default values (no
  `cluster.version` / `cluster.metaVersion` override)
- **THEN** the rendered `Kafka` manifest's `spec.kafka` block contains no `version` key and no
  `metadataVersion` key

#### Scenario: an explicit version override renders verbatim
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with
  `--set cluster.version=4.0.0 --set cluster.metaVersion=4.0`
- **THEN** the rendered `Kafka` manifest's `spec.kafka.version` is `4.0.0` and
  `spec.kafka.metadataVersion` is `"4.0"`

### Requirement: subchart Strimzi resources land in the Helm release namespace
The subchart's `Kafka` and `KafkaNodePool` resources SHALL render `metadata.namespace` from `.Release.Namespace` (the namespace `helm install -n <ns>` was given), not the hardcoded `eyelevel` literal the chart used before this change.

Polarity: reject the hardcoded literal / accept the release namespace, whatever it is.

#### Scenario: default namespace install
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with no explicit
  `--namespace` (Helm's default `default` namespace, or an install with `-n eyelevel`)
- **THEN** the rendered `Kafka` and `KafkaNodePool` manifests' `metadata.namespace` equals the
  namespace `helm template`/`helm install` was invoked with — never a hardcoded `eyelevel` string
  independent of that invocation

#### Scenario: non-default namespace install
- **WHEN** `helm template groundx-kafka-cluster src/groundx/prereqs/kafka-cluster -n
  groundx-validation` renders the subchart
- **THEN** the rendered `Kafka` and `KafkaNodePool` manifests' `metadata.namespace` is
  `groundx-validation`, not `eyelevel`

### Requirement: the main-chart KafkaTopic namespace stays paired with the Kafka bootstrap service's namespace
The main chart's `KafkaTopic` resources SHALL keep rendering `metadata.namespace` from `groundx.ns` (`.Values.namespace`, default `eyelevel`) — unchanged by this feature — so it resolves to the same namespace as the Kafka bootstrap DNS name the main chart constructs (`<serviceName>-cluster-kafka-bootstrap.<groundx.ns>.svc.cluster.local`), keeping a subchart install whose `-n <ns>` equals the main chart's `.Values.namespace` working exactly as before this change.

Polarity: backward compatibility (cross-service touchpoint — the main chart's namespace behavior is a fixed point this feature must not move) — old callers of the main chart that never set `.Values.namespace` continue to get `eyelevel` end to end, unaffected by the subchart's move to `.Release.Namespace`.

#### Scenario: KafkaTopic namespace matches the bootstrap host's namespace (default)
- **WHEN** `helm template` renders `src/groundx` with default values
- **THEN** every rendered `KafkaTopic`'s `metadata.namespace` is `eyelevel`, matching the
  namespace segment of the rendered `stream-cluster-kafka-bootstrap.eyelevel.svc.cluster.local`
  bootstrap host the chart's summary/queue clients are configured against

#### Scenario: backward compatibility — main-chart namespace override is unaffected by this change
- **WHEN** `helm template` renders `src/groundx` with `--set namespace=custom-ns` (as it could
  before this change)
- **THEN** every rendered `KafkaTopic`'s `metadata.namespace` is `custom-ns`, exactly matching
  pre-change behavior — this feature only changes the **subchart's** namespace source, never the
  main chart's `groundx.ns` resolution

### Requirement: the in-cluster replication factor never exceeds the broker count
A `.Values.cluster.replicas` greater than `.Values.nodepool.replicas` SHALL fail the render before any resource is emitted, because the `Kafka` CR's `config` block still derives `default.replication.factor`, `offsets.topic.replication.factor`, `transaction.state.log.replication.factor`, `transaction.state.log.min.isr`, and `min.insync.replicas` from `.Values.cluster.replicas` — a value now fully decoupled from the actual broker count, which lives on `.Values.nodepool.replicas` — so an unguarded excess would install a `Kafka` CR whose replication factors the broker count cannot satisfy.

Polarity: reject before state — no `Kafka`/`KafkaNodePool` manifest is emitted for an invalid combination; nothing partially renders.

#### Scenario: cluster.replicas exceeding nodepool.replicas fails the render
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with
  `--set cluster.replicas=3 --set nodepool.replicas=1`
- **THEN** the render fails with an error naming `cluster.replicas`/`nodepool.replicas`, and no
  `Kafka` or `KafkaNodePool` manifest is emitted

#### Scenario: cluster.replicas at or below nodepool.replicas renders successfully
- **WHEN** `helm template` renders `src/groundx/prereqs/kafka-cluster` with default values
  (`cluster.replicas: 1`, `nodepool.replicas: 1`)
- **THEN** the render succeeds and the `Kafka` manifest's `spec.kafka.config` replication-factor
  keys all equal `1`
