# strimzi-kafka-v1-compat Specification

## Purpose
TBD - created by archiving change gx-25-groundx-strimzi-kafka-cluster-mode-2-bundled-kafka-install. Update Purpose after archive.
## Requirements
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

### Requirement: the subchart's published version stays aligned across Chart.yaml, its README install example, and the harness's contract reference
The `groundx-strimzi-kafka-cluster` subchart's `Chart.yaml` `version` field, its own `helm/` mirror, and the `README.md` `helm install ... --version` example (both `src/groundx/` and `helm/`) SHALL all carry the identical `0.2.7` string, so the chart itself, the install docs a customer copies, and the version `contract.md` names as the producer→consumer touchpoint with `groundx-studio-harness` never disagree about which version is current.

Polarity: reject before state — a commit that bumps `Chart.yaml` without also updating the README example (or updates one mirror but not the other) leaves the four locations inconsistent; the change is not complete until all four read the same string.

#### Scenario: Chart.yaml carries 0.2.7 in both the source and the mirror
- **WHEN** `src/groundx/prereqs/kafka-cluster/Chart.yaml` and `helm/prereqs/kafka-cluster/Chart.yaml` are read
- **THEN** both `version` fields equal `0.2.7`

#### Scenario: the README install example matches the Chart.yaml version, in both the source and the mirror
- **WHEN** `src/groundx/prereqs/kafka-cluster/README.md` and `helm/prereqs/kafka-cluster/README.md` are read
- **THEN** both contain a `helm install ... --version 0.2.7` example, and neither contains a
  `--version 0.2.0` (or any other stale version) example

#### Scenario: backward compatibility — a consumer still pinned to the previously published version keeps resolving it
- **WHEN** a consumer runs `helm show chart groundx/groundx-strimzi-kafka-cluster --version 0.2.6`
  (the last version published before this increment) against the chart registry, during the window
  before `groundx-studio-harness`'s own PR cuts over its doc references to `0.2.7`
- **THEN** the previously published `0.2.6` artifact still resolves — this increment publishes a new
  version alongside the existing ones, it does not remove or replace an already-published version, so
  a not-yet-updated consumer reference keeps working until it is deliberately re-pointed

### Requirement: the subchart README documents an exact, ordered v1beta2 -> v1 upgrade runbook for an existing 0.1.x install
The subchart's `README.md` "Upgrading an existing 0.1.x install" section (both `src/groundx/` and its `helm/` mirror) SHALL name, in order: (1) upgrading the Strimzi operator in place to `0.50.1` as the dual-serving stepping-stone between a `v1beta2`-only operator and a `v1`-only one; (2) applying the operator release's CRD bundle so every Strimzi CRD serves both `v1beta2` and `v1` (because `helm upgrade` does not upgrade CRDs, and the conversion tool refuses to run until they do); (3) running Strimzi's `strimzi-v1-api-conversion` tool plus the CRD upgrade against the existing `Kafka`/`KafkaNodePool` resources while the 0.50.1 operator is still running, converting the stored CRD version to `v1` in place; (4) only then running `helm upgrade` to chart `0.2.7`; (5) pinning `cluster.version`/`cluster.metaVersion` to the already-running Kafka version across the whole hop; (6) keeping the upgrade's release namespace equal to the old install's `.Values.namespace`; and (7) pre-checking `cluster.replicas <= nodepool.replicas` before upgrading. It SHALL state explicitly that CRDs are converted in place and never deleted and recreated, because deleting a Strimzi CRD deletes the `Kafka`/`KafkaNodePool` objects Kubernetes tracks under it.

Polarity: reject before state — a runbook missing the stepping-stone version, the conversion-tool step, or the convert-never-delete constraint documents an upgrade path that can destroy the running cluster's control-plane object; the requirement is not met by an incomplete list.

#### Scenario: the runbook names the stepping-stone operator version and the conversion tool, in both copies
- **WHEN** `src/groundx/prereqs/kafka-cluster/README.md` and `helm/prereqs/kafka-cluster/README.md` are read
- **THEN** both contain the literal string `0.50.1` and the literal string `strimzi-v1-api-conversion`
  somewhere in the "Upgrading an existing 0.1.x install" section

#### Scenario: the runbook states CRDs are converted, never deleted and recreated
- **WHEN** `src/groundx/prereqs/kafka-cluster/README.md` and `helm/prereqs/kafka-cluster/README.md` are read
- **THEN** both state the CRD upgrade is an in-place conversion and warn against deleting and
  recreating the CRDs

#### Scenario: the runbook orders the operator upgrade before the chart upgrade
- **WHEN** the "Upgrading an existing 0.1.x install" section is read as an ordered procedure
- **THEN** the Strimzi operator upgrade to `0.50.1` and the CRD conversion step appear before the
  `helm upgrade` to chart `0.2.7` step — never after

### Requirement: an automated kind CI job proves the v1beta2 -> v1 migration runbook keeps the running cluster and its topics Ready throughout
The `.github/workflows/kafka-strimzi-kind.yml` workflow SHALL carry a job, additive alongside the existing `live-strimzi-kind` job (which stays unchanged), that installs the old Strimzi operator `0.47.0` and the vendored old subchart package `helm-releases/groundx-strimzi-kafka-cluster-0.1.1.tgz` (both `v1beta2`-shaped), waits for the `Kafka` cluster and its `KafkaTopic`s to reach `Ready`, then drives the documented runbook — the conversion tool, the CRD upgrade, the operator upgrade to `0.50.1`, and the `helm upgrade` to the current (post-increment-1, `v1`-shaped) chart — and asserts the `Kafka` custom resource and every `KafkaTopic` custom resource stay `Ready` through the whole conversion, not merely at the end. This is a gate-class change (a new CI job that decides pass/fail on the migration path) and it must catch the adversarial counterexample below while never blocking the legitimate one.

Polarity: this is a gate-class requirement — it must catch the adversarial counterexample below and must not block the legitimate one.

#### Scenario: catches — deleting and recreating the CRD instead of converting it in place breaks the running cluster
- **WHEN** the migration steps delete and recreate the `Kafka`/`KafkaNodePool` CRDs instead of running
  `strimzi-v1-api-conversion` in place, and the kind upgrade-test job runs the runbook against the
  old `0.1.1` install
- **THEN** the job fails — the previously-`Ready` `Kafka` custom resource and/or its `KafkaTopic`s are
  no longer present or no longer report `Ready` at some point during the conversion, and the job does
  not report success

#### Scenario: must not block — the documented runbook, executed in order, keeps the cluster and every topic Ready throughout
- **WHEN** the kind upgrade-test job installs the old operator `0.47.0` and chart `0.1.1`, waits for
  `Ready`, then executes the documented runbook in order (operator to `0.50.1`, conversion tool, CRD
  upgrade, `helm upgrade` to `0.2.7`)
- **THEN** the `Kafka` custom resource and all five `KafkaTopic` custom resources remain `Ready`
  throughout the conversion, and the job passes

#### Scenario: the workflow file is valid YAML
- **WHEN** `.github/workflows/kafka-strimzi-kind.yml` is parsed by a YAML parser
- **THEN** parsing succeeds with no error — a step name or value containing an unquoted `:` (the
  known past failure mode for this file) does not break the document

### Requirement: the air-gapped Chainguard Strimzi values carry a supported operator image and Kafka cluster version
`src/groundx/values/chainguard/values.strimzi.operator.yaml` and its `helm/` mirror SHALL pin every Strimzi image `tag`/`tagPrefix` to `v0.50.1` (a dual-serving release that serves both `kafka.strimzi.io/v1beta2` and `kafka.strimzi.io/v1` and still supports Apache Kafka `4.0.x` through `4.1.x`; the exact `cgr.dev/eyelevel.ai` tag string is pending a human `crane ls` spot-check before the air-gapped publish), replacing the prior `v0.48.0` and keeping the values file's established `v`-prefixed tag convention. `src/groundx/values/chainguard/values.strimzi.cluster.yaml` and its `helm/` mirror SHALL leave `cluster.version` unset, replacing the prior explicit `4.1.0` pin, matching the main v1 chart's greenfield default of leaving `cluster.version`/`cluster.metaVersion` unset so the operator selects a supported default.

Polarity: reject the unsupported pinned values (`v0.48.0` operator image, `cluster.version: 4.1.0`) / accept the air-gapped path matching the already-shipped greenfield default (an unset cluster version, a `v1`-capable operator image).

#### Scenario: the Chainguard operator image is pinned to v0.50.1 in both the source and the mirror
- **WHEN** `src/groundx/values/chainguard/values.strimzi.operator.yaml` and its `helm/` mirror are read
- **THEN** every image `tag`/`tagPrefix` key equals `v0.50.1`, and `v0.48.0` does not appear anywhere
  in either file

#### Scenario: the Chainguard cluster version is unset, matching the greenfield default, in both the source and the mirror
- **WHEN** `src/groundx/values/chainguard/values.strimzi.cluster.yaml` and its `helm/` mirror are read
- **THEN** neither file sets a `cluster.version` value, and `4.1.0` does not appear in either file

