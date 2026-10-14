## ADDED Requirements

### Requirement: AIStor operator sample values remove the cluster-wide pod webhook and certificate approval

`src/groundx/values/aistor/values.operator.yaml` and its byte-identical copy `helm/values/aistor/values.operator.yaml` SHALL set `global.operator.nodeSelector.node: eyelevel-cpu-only`, `global.operator.optOutAutomaticCertificates: true`, and `operators.object-store.webhook.enabled: false` for the `aistor-operator` chart 6.0.0 from `https://helm.min.io/`. Validated by `helm template` (helm v3.19.0) of the pulled chart, reading named fields only.

#### Scenario: GroundX operator values render no webhook and no certificate approval (finalize success)
- **GIVEN** `aistor-operator` 6.0.0 rendered into namespace `aistor` once with no values file and once with `values/aistor/values.operator.yaml`
- **WHEN** `helm template` runs both renders
- **THEN** the render without the file contains one `MutatingWebhookConfiguration` and five `ClusterRoleBinding`s, so the opt-outs are not chart defaults
- **AND** the render with the file contains no `MutatingWebhookConfiguration`, no `ClusterRoleBinding` whose name contains `certificate`, and two `ClusterRoleBinding`s in total
- **AND** every `Deployment` it renders has `nodeSelector.node: eyelevel-cpu-only`

#### Scenario: Operator values are byte-identical in both chart trees (finalize success)
- **WHEN** `cmp` compares `src/groundx/values/aistor/values.operator.yaml` with `helm/values/aistor/values.operator.yaml`
- **THEN** the files are identical

### Requirement: AIStor object store sample values reuse GroundX's default store hosts

`values/aistor/values.objectstore.yaml` (both trees, byte-identical) SHALL configure the `aistor-objectstore` chart 1.1.0 for a fresh install: `objectStore.name: minio-tenant`, `certificates.disableAutoCert: true`, one pool with one server and one volume, `nodeSelector.node: eyelevel-cpu-only`, and root credentials read from an existing Secret named by `secrets.name` with `secrets.existingSecret: true`. The file SHALL contain no credentials. Named `minio-tenant` with TLS off, the store serves the hosts the GroundX chart already uses (`minio`, `minio-tenant-hl`), so GroundX needs no `file` settings.

#### Scenario: Fresh-install values render the store GroundX expects (finalize success)
- **GIVEN** `aistor-objectstore` 1.1.0 and `values/aistor/values.objectstore.yaml`
- **WHEN** `helm template` renders it into namespace `eyelevel`
- **THEN** exactly one `ObjectStore` is rendered, named `minio-tenant`, with `spec.certificates.disableAutoCert: true`, one pool, `servers: 1`, and `nodeSelector.node: eyelevel-cpu-only`
- **AND** `spec.configuration.name` names the existing credentials Secret
- **AND** the render contains no `Secret`, so no credentials come from the values file

#### Scenario: The well-known sample credentials are refused (reject before state)
- **GIVEN** the same values with `secrets.existingSecret=false`, `secrets.accessKey=minio`, and `secrets.secretKey=minio123`
- **WHEN** `helm template` runs
- **THEN** the render fails with the chart's "well-known weak pair" error and produces no `Secret` and no `ObjectStore`

#### Scenario: Object store values are byte-identical in both chart trees (finalize success)
- **WHEN** `cmp` compares the `src/groundx` and `helm` copies of `values/aistor/values.objectstore.yaml`
- **THEN** the files are identical

### Requirement: The upgrade example keeps the 0.2.7 tenant's volume and credentials

`values/aistor/values.objectstore.upgrade.yaml` (both trees, byte-identical) SHALL show the `aistor-objectstore` values for a tenant that was installed from GroundX's 0.2.7 sample values: object store `minio-tenant`, pool `minio-tenant-pool-0` with one server, one volume and `20Gi`, `certificates.disableAutoCert: true`, and credentials from an existing Secret (`secrets.existingSecret: true`) whose name differs from the tenant-owned Secret `myminio-env-configuration`.

#### Scenario: Upgrade example renders against the existing volume (finalize success)
- **GIVEN** `aistor-objectstore` 1.1.0 and `values/aistor/values.objectstore.upgrade.yaml`
- **WHEN** `helm template` renders it into namespace `eyelevel`
- **THEN** one `ObjectStore` named `minio-tenant` is rendered with pool name `minio-tenant-pool-0`, `servers: 1`, `volumesPerServer: 1`, a `20Gi` volume claim, and `disableAutoCert: true`
- **AND** `spec.configuration.name` is set and is not `myminio-env-configuration`
- **AND** the render contains no `Secret`

#### Scenario: Upgrade example is byte-identical in both chart trees (finalize success)
- **WHEN** `cmp` compares the two copies
- **THEN** the files are identical

### Requirement: The README installs AIStor with the customer's license

`README.md` SHALL replace `### MinIO` with `### MinIO AIStor` and SHALL contain `#### Deploying a Dedicated AIStor Object Store`, listed in the table of contents. That section's first `bash` block SHALL start with `helm repo add minio https://helm.min.io/`, a line that appears exactly once in the README. The section SHALL install `aistor-operator` with `--version 6.0.0` and `-f helm/values/aistor/values.operator.yaml`, and `aistor-objectstore` with `--version 1.1.0` and `-f helm/values/aistor/values.objectstore.yaml`. It SHALL create the customer's license as Secret `minio-license` with key `minio.license` in the operator's namespace, show how to confirm the store reached `Initialized` with the license in place, and state that without the license the object store is not created and GroundX waits for storage. It SHALL NOT reference `operator.min.io`.

#### Scenario: Fresh-install block is the first match for its first line (finalize success)
- **GIVEN** the updated README
- **WHEN** the section under `#### Deploying a Dedicated AIStor Object Store` is read
- **THEN** its first `bash` block starts with `helm repo add minio https://helm.min.io/`
- **AND** that line occurs once in the README
- **AND** the section contains `--version 6.0.0`, `--version 1.1.0`, `minio-license`, `minio.license`, both AIStor values file paths, and `Initialized`, and does not contain `operator.min.io`

#### Scenario: Missing license is documented, not hidden (finalize failure)
- **GIVEN** a cluster where the operator and object store were installed but Secret `minio-license` was not created
- **WHEN** an operator follows the README's license check
- **THEN** the README tells them the store is not created and GroundX keeps waiting for storage until the Secret exists, and it does not describe the install as complete

### Requirement: The README upgrades an existing community MinIO install in place

`README.md` SHALL contain `#### Upgrading an Existing MinIO Install to AIStor` after the fresh-install section. The section SHALL state that the upgrade cannot be reversed, require Helm 3.17 or later, and give, in order: a `VolumeSnapshot` of the tenant volume before any `helm uninstall`; stopping uploads; installing `aistor-operator` with `--take-ownership` and the license; backing up the tenant; running `operator-migration generate-helm` from the image pinned by digest `sha256:4ac3380d75aa92ca3c03454af2362a649ce4ddee866c962044e4b6e6d118b957`, never `:latest`; copying the tenant's `config.env` into a new Secret and setting `secrets.existingSecret: true` (with `helm/values/aistor/values.objectstore.upgrade.yaml` as the example); uninstalling the tenant; installing `aistor-objectstore` with `--take-ownership`; confirming `Initialized`; and, optionally, running `protect-crds` before uninstalling the old operator. It SHALL state that a multi-server tenant needs a paid license.

The section SHALL also name the snapshot prerequisites, a snapshot controller and a `VolumeSnapshotClass`, which GroundX's bundled EKS Terraform does not install. The backup SHALL write the Tenant and the Secrets to separate files and append nothing with `>>`, SHALL save both community releases' values with `helm get values minio-cluster` and `helm get values minio-operator` and warn that the tenant values hold the root credentials, and SHALL record the tenant's claim name, StorageClass, size, and the Tenant's `.spec.image` for the restore. It SHALL give `operator-migration` a kubeconfig made with `kubectl config view --flatten --minify` that works inside the container, and SHALL say that a kubeconfig logging in through an exec plugin such as `aws eks get-token` is not verified.

#### Scenario: Snapshot comes before any uninstall (reject before state)
- **GIVEN** the upgrade section
- **WHEN** the first `VolumeSnapshot` line and the first `helm uninstall` line are compared
- **THEN** the snapshot line comes first, so no step removes the tenant before its volume is captured

#### Scenario: Shared CRD is protected before the old operator is removed (reject before state)
- **WHEN** the `protect-crds` line and the last `helm uninstall` line are compared
- **THEN** `protect-crds` comes first, so uninstalling the community operator cannot delete the `policybindings.sts.min.io` CRD AIStor now uses

#### Scenario: Migration tool is pinned (finalize success)
- **WHEN** the README is searched for `operator-migration:latest`
- **THEN** there is no match, and the upgrade section names `quay.io/minio/aistor/operator-migration` with the pinned digest

#### Scenario: The backup stays readable and holds what the restore needs (reject before state)
- **GIVEN** the upgrade section
- **WHEN** it is searched for `>>`
- **THEN** there is no match, so the Secrets list is never appended to the Tenant backup, where the two would parse as one document whose `.kind` is `List`
- **AND** the section contains `helm get values minio-cluster`, `helm get values minio-operator`, `storageClassName`, `.spec.image`, `--flatten`, and `VolumeSnapshotClass`

### Requirement: The README restores community MinIO from the pre-upgrade snapshot

`README.md` SHALL contain `#### Restoring Community MinIO from the Pre-Upgrade Snapshot` after the upgrade section. It SHALL restore the tenant volume from the `VolumeSnapshot` and start a community MinIO tenant on it with the customer's own registry copy of the tenant's MinIO server image when they have one, otherwise `ghcr.io/coollabsio/minio@sha256:69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9`. It SHALL state that objects written after the snapshot are not restored. No part of the README SHALL reference `helm/values/minio/`.

The section SHALL require Helm 3.17 or later and give, in order: uninstalling the AIStor object store release; deleting ServiceAccount `minio-tenant-sa`, which AIStor leaves behind; deleting the AIStor-era claim and creating a claim with the same name from the `VolumeSnapshot`, with the StorageClass and size recorded before the upgrade; installing community operator chart 7.1.1 with `--take-ownership` and the saved operator values, marked untested; and installing community tenant chart 7.1.1 as release `minio-cluster` with the saved tenant values and the image override (the mirror as `tenant.image.repository` plus `tenant.image.digest`, the customer's copy as repository plus tag, marked untested). It SHALL recommend deleting the other AIStor leftovers in `eyelevel` (RoleBinding `minio-tenant-eyelevel-binding`, Secrets `minio-tenant-generated`, `minio-license`, and `minio-tenant-env-configuration`), and it SHALL NOT tell the reader to wait for the restored claim to bind, because GroundX's StorageClass binds only when a pod uses the claim.

#### Scenario: Restore names a pullable image and no deleted file (finalize success)
- **GIVEN** the restore section
- **THEN** it contains `VolumeSnapshot`, the word `registry` for the customer's own copy, the digest-pinned mirror image, `--take-ownership`, and `3.17`
- **AND** the README contains no `helm/values/minio/`

#### Scenario: The leftover ServiceAccount is deleted before the community tenant is installed (reject before state)
- **GIVEN** the restore section
- **WHEN** the first line that deletes `minio-tenant-sa` and the first line that installs `minio-cluster` are compared
- **THEN** a deletion line exists and comes first, so the community operator cannot reuse the ServiceAccount AIStor left behind

#### Scenario: The restore does not wait for the claim to bind (reject before state)
- **WHEN** the restore section is searched for a `wait` command whose `--for` condition is `Bound`
- **THEN** there is no match, so a reader on GroundX's StorageClass is not left waiting on a claim that binds only when the tenant pod starts

### Requirement: The README documents staying on community MinIO and its risk

`README.md` SHALL contain `#### Staying on Community MinIO` after the restore section. It SHALL state that community MinIO receives no fixes, that its default server image no longer downloads anonymously, and that a tenant pod rescheduled to another node may not start unless the running image has been copied to the customer's own registry.

#### Scenario: Staying is documented with its risk (finalize success)
- **WHEN** the section is read
- **THEN** it exists, is linked from the table of contents, and tells the reader to keep a copy of the running image in their own registry

### Requirement: Object keys with a leading slash are renamed before upgrading to chart 0.2.8

`README.md` SHALL contain `#### Object Keys That Start with a Slash`, between the fresh-install and upgrade sections. It SHALL state that a store connected as `serviceType: minio` that keeps a leading `/` in object keys needs those keys renamed before the upgrade to chart 0.2.8, because 0.2.8 services look keys up without the slash, and that a rollback to chart 0.2.7 needs the rename reversed. It SHALL give a way to list affected keys and rename them.

#### Scenario: Rename and its reversal are documented (finalize success)
- **WHEN** the section is read
- **THEN** it contains `serviceType: minio`, `0.2.8`, and `0.2.7`, and is linked from the table of contents

### Requirement: Community MinIO sample values stop shipping while installed stores keep working

The community MinIO operator and tenant sample values SHALL no longer ship: `src/groundx/values/minio/` and `helm/values/minio/` are deleted. Installed MinIO tenants (separate Helm releases), the `minio` storage-type value, the chart's default store hosts and credentials comments, every chart template and default, the helm-unittest snapshots, and the Chainguard MinIO seeds SHALL remain unchanged.

#### Scenario: Legacy sample files are gone and nothing points at them (finalize success)
- **WHEN** the working tree is checked
- **THEN** neither `values/minio/` directory exists and no file outside `openspec/changes/`, `bin/operator`, and `terraform/groundx-operator/` contains `values/minio/`

#### Scenario: Existing installs render the same objects (finalize success)
- **GIVEN** the base commit's chart with this change's `Chart.yaml` copied in, and this change's chart
- **WHEN** both are rendered with no values file (bundled store), `values/minikube/values.yaml`, `values/values.existing.yaml` (`serviceType: minio`), `values/values.aws.services.yaml`, `mode=ingest`, and `mode=search`, for both `src/groundx` and `helm`
- **THEN** each pair of renders is byte-identical

### Requirement: No community-MinIO install text remains outside the allowed places

After the change, a reader following any document in this repo to install a store SHALL be pointed at AIStor or S4, never at community MinIO. Community-MinIO install markers (`operator.min.io`, `minio-operator/operator`, `minio-operator/tenant`, `values/minio/`, `quay.io/minio/minio:`) SHALL appear only in the README from `#### Upgrading an Existing MinIO Install to AIStor` to the next `### ` heading, and in the unchanged out-of-scope files (`bin/operator`, `terraform/groundx-operator/**`, `*/values/chainguard/**`). Every file whose path or content contains `minio` (case-insensitive), outside `openspec/changes/**` and `src/groundx/tests/__snapshot__/**`, SHALL be on the allowlist recorded in this change's design.md.

#### Scenario: A legacy install command under the AIStor heading is caught (finalize failure)
- **GIVEN** a README where `helm repo add minio-operator https://operator.min.io/` sits under `#### Deploying a Dedicated AIStor Object Store`
- **WHEN** the marker scan runs
- **THEN** the scan fails and names that line, even though the heading says AIStor

#### Scenario: Upgrade and restore steps that name community MinIO pass (finalize success)
- **GIVEN** a README whose upgrade and restore sections use `helm uninstall minio-operator`, `helm repo add minio-operator https://operator.min.io/`, and `minio-operator/tenant`, and whose other text uses `serviceType: minio`, `minio-tenant-hl`, and `minio-license`
- **WHEN** the marker scan runs
- **THEN** the scan passes

#### Scenario: A file outside the allowlist that mentions MinIO is caught (finalize failure)
- **GIVEN** a tracked or untracked, non-ignored file outside the allowlist whose path or content contains `minio`
- **WHEN** the allowlist scan runs
- **THEN** the scan fails and names the file

### Requirement: Store wording names AIStor as the default and S4 as an option

`sample.values.yaml` SHALL replace `file.username: minio` and `file.password: minio123` with placeholders for the store's own credentials and SHALL contain no `minio` text. `src/groundx/values/README.md` and its byte-identical `helm/` copy SHALL list `aistor` and `s4` folders and no `minio` folder. `AGENTS.md`, `ARCHITECTURE_NOTES.md`, `service.yaml`, and `openspec/config.yaml` SHALL describe the store as MinIO AIStor (default), AWS S3, or S4, SHALL list the AIStor Helm repository instead of the community MinIO one, and SHALL describe `minio123` only where it still ships (the unchanged Chainguard sample values).

#### Scenario: Sample credentials are placeholders (reject before state)
- **WHEN** `yq` reads `.file.username` and `.file.password` from `sample.values.yaml`
- **THEN** both are set, neither is `minio` or `minio123`, and the file contains no `minio` text

#### Scenario: Repo docs no longer name community MinIO as the store (finalize success)
- **WHEN** the four repo docs are searched
- **THEN** none contains ``MinIO `minio123` `` or `percona, minio, strimzi`, `service.yaml` contains no `minio-s3` or `percona/minio/`, and `ARCHITECTURE_NOTES.md`, `service.yaml`, and `openspec/config.yaml` each name AIStor and S4
- **AND** both `values/README.md` copies list `aistor` and `s4`, list no `minio` folder, and are byte-identical
