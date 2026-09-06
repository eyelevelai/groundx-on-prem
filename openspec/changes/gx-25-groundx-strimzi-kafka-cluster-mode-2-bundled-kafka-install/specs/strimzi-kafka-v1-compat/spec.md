## ADDED Requirements

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
The subchart's `README.md` "Upgrading an existing 0.1.x install" section (both `src/groundx/` and its `helm/` mirror) SHALL name, in order: (1) upgrading the Strimzi operator in place to `0.51.0` as the dual-serving stepping-stone between a `v1beta2`-only operator and a `v1`-only one; (2) running Strimzi's `strimzi-v1-api-conversion` tool plus the CRD upgrade against the existing `Kafka`/`KafkaNodePool` resources while the 0.51.0 operator is still running, converting the stored CRD version to `v1` in place; (3) only then running `helm upgrade` to chart `0.2.7`; (4) pinning `cluster.version`/`cluster.metaVersion` to the already-running Kafka version across the whole hop; (5) keeping the upgrade's release namespace equal to the old install's `.Values.namespace`; and (6) pre-checking `cluster.replicas <= nodepool.replicas` before upgrading. It SHALL state explicitly that CRDs are converted in place and never deleted and recreated, because deleting a Strimzi CRD deletes the `Kafka`/`KafkaNodePool` objects Kubernetes tracks under it.

Polarity: reject before state — a runbook missing the stepping-stone version, the conversion-tool step, or the convert-never-delete constraint documents an upgrade path that can destroy the running cluster's control-plane object; the requirement is not met by an incomplete list.

#### Scenario: the runbook names the stepping-stone operator version and the conversion tool, in both copies
- **WHEN** `src/groundx/prereqs/kafka-cluster/README.md` and `helm/prereqs/kafka-cluster/README.md` are read
- **THEN** both contain the literal string `0.51.0` and the literal string `strimzi-v1-api-conversion`
  somewhere in the "Upgrading an existing 0.1.x install" section

#### Scenario: the runbook states CRDs are converted, never deleted and recreated
- **WHEN** `src/groundx/prereqs/kafka-cluster/README.md` and `helm/prereqs/kafka-cluster/README.md` are read
- **THEN** both state the CRD upgrade is an in-place conversion and warn against deleting and
  recreating the CRDs

#### Scenario: the runbook orders the operator upgrade before the chart upgrade
- **WHEN** the "Upgrading an existing 0.1.x install" section is read as an ordered procedure
- **THEN** the Strimzi operator upgrade to `0.51.0` and the CRD conversion step appear before the
  `helm upgrade` to chart `0.2.7` step — never after

### Requirement: an automated kind CI job proves the v1beta2 -> v1 migration runbook keeps the running cluster and its topics Ready throughout
The `.github/workflows/kafka-strimzi-kind.yml` workflow SHALL carry a job, additive alongside the existing `live-strimzi-kind` job (which stays unchanged), that installs the old Strimzi operator `0.47.0` and the vendored old subchart package `helm-releases/groundx-strimzi-kafka-cluster-0.1.1.tgz` (both `v1beta2`-shaped), waits for the `Kafka` cluster and its `KafkaTopic`s to reach `Ready`, then drives the documented runbook — the conversion tool, the CRD upgrade, the operator upgrade to `0.51.0`, and the `helm upgrade` to the current (post-increment-1, `v1`-shaped) chart — and asserts the `Kafka` custom resource and every `KafkaTopic` custom resource stay `Ready` through the whole conversion, not merely at the end. This is a gate-class change (a new CI job that decides pass/fail on the migration path) and it must catch the adversarial counterexample below while never blocking the legitimate one.

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
  `Ready`, then executes the documented runbook in order (operator to `0.51.0`, conversion tool, CRD
  upgrade, `helm upgrade` to `0.2.7`)
- **THEN** the `Kafka` custom resource and all five `KafkaTopic` custom resources remain `Ready`
  throughout the conversion, and the job passes

#### Scenario: the workflow file is valid YAML
- **WHEN** `.github/workflows/kafka-strimzi-kind.yml` is parsed by a YAML parser
- **THEN** parsing succeeds with no error — a step name or value containing an unquoted `:` (the
  known past failure mode for this file) does not break the document

### Requirement: the air-gapped Chainguard Strimzi values carry a supported operator image and Kafka cluster version
`src/groundx/values/chainguard/values.strimzi.operator.yaml` and its `helm/` mirror SHALL pin every Strimzi image `tag`/`tagPrefix` to `v0.51.0` (a release confirmed to exist in the Chainguard mirror under both the `0.51.0` and `v0.51.0` tags, and to serve both `kafka.strimzi.io/v1beta2` and `kafka.strimzi.io/v1`), replacing the prior `v0.48.0` and keeping the values file's established `v`-prefixed tag convention. `src/groundx/values/chainguard/values.strimzi.cluster.yaml` and its `helm/` mirror SHALL leave `cluster.version` unset, replacing the prior `4.1.0` (a Kafka version no current Strimzi release supports), matching the main v1 chart's greenfield default of leaving `cluster.version`/`cluster.metaVersion` unset.

Polarity: reject the unsupported pinned values (`v0.48.0` operator image, `cluster.version: 4.1.0`) / accept the air-gapped path matching the already-shipped greenfield default (an unset cluster version, a `v1`-capable operator image).

#### Scenario: the Chainguard operator image is pinned to v0.51.0 in both the source and the mirror
- **WHEN** `src/groundx/values/chainguard/values.strimzi.operator.yaml` and its `helm/` mirror are read
- **THEN** every image `tag`/`tagPrefix` key equals `v0.51.0`, and `v0.48.0` does not appear anywhere
  in either file

#### Scenario: the Chainguard cluster version is unset, matching the greenfield default, in both the source and the mirror
- **WHEN** `src/groundx/values/chainguard/values.strimzi.cluster.yaml` and its `helm/` mirror are read
- **THEN** neither file sets a `cluster.version` value, and `4.1.0` does not appear in either file
