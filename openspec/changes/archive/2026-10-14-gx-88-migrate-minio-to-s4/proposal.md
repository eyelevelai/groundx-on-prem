## Why

The README's "Deploying a Dedicated MinIO Cluster" steps install the community MinIO operator and tenant charts from `https://operator.min.io/` with `values/minio/values.{operator,tenant}.yaml`. Community MinIO is archived: GitHub lists `minio/minio` and `minio/operator` as archived (checked 2026-10-14), and on 2026-10-14 quay.io refused an anonymous pull of `quay.io/minio/minio:RELEASE.2025-04-08T15-41-24Z`, the server image the tenant chart 7.1.1 defaults to, with HTTP 401. A customer following the guide on a new cluster no longer gets a working store, and existing MinIO installs have no maintained path forward in our docs.

GroundX ships only sample values and README steps for the store; the chart has no MinIO dependency and passes the storage type to the services unchanged. So this change is guidance, sample values, and the chart version: MinIO AIStor (MinIO's maintained product, run under the customer's own license) becomes the documented default, with an in-place upgrade for existing MinIO installs; S4 is documented as a license-free alternative through the new `s4` storage type that the GX-88 changes add to cashbot-go, ai-server, and groundx-python; and the chart moves to 0.2.8 so its default image tags pick up those service releases.

## What Changes

- **BREAKING (sample files only):** delete `src/groundx/values/minio/values.operator.yaml`, `src/groundx/values/minio/values.tenant.yaml`, and their `helm/values/minio/` copies. Installed MinIO tenants are separate Helm releases and this change does not touch them; the `minio` storage type, the chart's default store host names, and every other chart default stay as they are; the Chainguard MinIO seeds (`values/chainguard/values.minio.*.yaml`) stay unchanged. Only scripts that pass `-f helm/values/minio/...` from a checkout of this repo stop working.
- Add AIStor sample values in `src/groundx/values/` and `helm/values/`, byte-identical:
  - an operator file: `operators.object-store.webhook.enabled: false`, `global.operator.optOutAutomaticCertificates: true`, `nodeSelector.node: eyelevel-cpu-only`;
  - an object-store file: `objectStore.name: minio-tenant`, `certificates.disableAutoCert: true`, one server, credentials from an existing Secret, `nodeSelector.node: eyelevel-cpu-only`;
  - an upgrade example with `secrets.existingSecret: true`.
- Add `values/s4/values.yaml` in both trees, byte-identical: S4 `0.3.2` pinned as `image.tag: "0.3.2@sha256:48d1875da2eb087f6b52e01f3e97daa750962a347132230c27d35878c48ce16f"`, `pullPolicy: IfNotPresent`, the OpenShift Route off, a pod `fsGroup`, a `ClusterIP` Service, and custom S3 and UI credentials.
- Rewrite the README storage section (table of contents and the current MinIO section):
  - **Fresh install** of `aistor-operator` and `aistor-objectstore` from `https://helm.min.io/`, pinned with `--version 6.0.0` and `--version 1.1.0`, the versions the GX-88 ticket specifies and tested. The AIStor repository added 6.1.0 and 1.2.0 on 2026-10-14, so an unpinned command would install untested charts. The customer's license goes in Secret `minio-license`, key `minio.license`. The guide shows how to confirm the license is in place and states that without it the store never starts and GroundX waits for storage.
  - **In-place upgrade** of an existing MinIO install: stop uploads and wait until no documents are still processing; then snapshot the disk, because the upgrade is one-way; install the AIStor operator with the license; back up the tenant; run `operator-migration generate-helm`; copy the tenant's `config.env` into a new Secret and set `secrets.existingSecret: true`; uninstall the tenant; install `aistor-objectstore` with `--take-ownership`; confirm `Initialized`; optionally remove the old operator. Multi-server tenants need a paid license.
  - **Restore** from the pre-upgrade snapshot back to community MinIO, using the customer's own registry copy of the tenant's MinIO server image if they have one, otherwise the digest-pinned mirror `ghcr.io/coollabsio/minio@sha256:69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9`.
  - **Staying on community MinIO**, with its risk.
  - **S4**, next to "Using AWS S3": `file.existing.serviceType: s4` with the S4 Service URL, S4's limits (single replica, the 5 GiB large-file limit, and the file-name length limit), minimum chart 0.2.8, production pointed at AIStor, and migration from MinIO by copying with the same keys, setting the public-read policy (object tags are not copied), and then handing Service `minio` to S4 so that GroundX keeps `url: http://minio.eyelevel.svc.cluster.local` (amended 2026-10-16; GroundX saves each file's full URL).
  - **Before upgrading to 0.2.8**, a store connected as `serviceType: minio` that keeps a leading `/` in object keys must have those keys renamed.
- Add `s4` to the `serviceType` comment at `src/groundx/values.yaml:74` and `helm/values.yaml:74`. Comment only; no default changes.
- Update the store wording in `sample.values.yaml` (the `minio`/`minio123` sample credentials become placeholders for the store's own credentials), `src/groundx/values/README.md` and its `helm/` copy, `AGENTS.md`, `ARCHITECTURE_NOTES.md`, `service.yaml`, and `openspec/config.yaml`.
- Bump `version` and `appVersion` from `0.2.7` to `0.2.8` in `src/groundx/Chart.yaml` and `helm/Chart.yaml`.
- Unchanged: every chart template, every `values.yaml` default, `values.schema.json`, the helm-unittest snapshots, the Chainguard MinIO files, `terraform/groundx-operator/**`, and `bin/operator`. After the change, no community-MinIO install step remains in this repo's docs except in the upgrade and restore steps and in those unchanged files.

## Capabilities

### New Capabilities
- `object-store-install-and-upgrade`: AIStor as the documented default store (sample values, pinned chart versions, license handling), the in-place upgrade from community MinIO and its restore path, staying on MinIO, the leading-slash rename step for stores connected as `minio` before 0.2.8, and the rule that no community-MinIO install step remains outside the allowed places.
- `s4-storage-type`: S4 as a documented storage type `s4`: the S4 sample values file, the `serviceType` comment, the README S4 section with its limits and copy migration, and chart 0.2.8 as the minimum version.

### Modified Capabilities
None. No spec under `openspec/specs/` covers the store sample values or the storage docs. `release-chart-artifacts` describes the 0.2.7 archive; no script in `.build/bin/` or workflow in `.github/workflows/` compares `helm/` with a chart archive, so this change leaves that requirement as it is. Packaging and publishing chart 0.2.8 stay a maintainer action (`src/build.sh`).

## Impact

- **Blast radius.** No template changes, so a render with the same values differs only where the chart version appears: default image tags, which follow `appVersion`, and the `appVersion` and `version` labels. Any cluster that upgrades to chart 0.2.8 (customer self-hosted installs, the validation EKS cluster, or any other cluster deployed from this chart) rolls every GroundX workload that uses default image tags onto the 0.2.8 images. Store releases (MinIO, AIStor, S4) are separate Helm releases the customer installs; upgrading the GroundX chart does not touch them.
- **What could break on rollout.**
  - A 0.2.8 image that does not exist yet: pods cannot pull it. The chart is published only after every image the chart defaults to exists at 0.2.8 and after the groundx-python release and the internal-arcadia-agents pin are out (the cross-repo release gates).
  - `serviceType: s4` with images older than 0.2.8, for example explicitly pinned tags: files go to AWS S3 or extraction fails at start. The docs state chart 0.2.8 as the minimum; explicitly pinned image tags are an accepted gap of that wording.
  - A store connected as `serviceType: minio` that keeps a leading `/` in keys: 0.2.8 services stop finding those keys until they are renamed (README step).
  - Scripts that reference the deleted `values/minio/` files.
  - groundx-studio-harness scanner check 9 pins the README's current MinIO install line (`scripts/scans/scan-on-prem.mjs:1381`), records a failure when the README no longer contains it (`:1432-1434`), and reads the first code block that contains its marker (`:1397-1405`). The AIStor fresh-install block must therefore come before the upgrade and restore blocks, and its first command line must be unique in the README. From this merge until the harness PR merges, a local harness scan against this repo's main fails check 9.
- **Data and stateful resources.** The chart changes no stateful resource. The documented AIStor upgrade is a customer-run change to the store's volume that MinIO documents as permanent and not reversible, so the guide starts with a disk snapshot and includes the restore. The S4 migration copies data, then uninstalls the MinIO store release and hands Service `minio` to S4; the store's volume claim and data stay.
- **Rollback and roll-forward.**
  - Chart: roll back to 0.2.7, which restores the 0.2.7 image tags. An install on `s4` must first go back to its MinIO or AIStor store (S4 below), because 0.2.7 images do not support `s4`. A store connected as `minio` whose slash-prefixed keys were renamed for 0.2.8 needs that rename reversed, because 0.2.7 services look those keys up with the leading `/` again. Roll forward by correcting values and upgrading again.
  - AIStor upgrade: no in-place rollback; the documented way back is restoring the pre-upgrade snapshot into a community MinIO tenant.
  - S4: delete Service `minio`, install the store release again from its saved values on the kept volume claim, and restore the previous `file` settings; files written only to S4 since the switch are not on MinIO.
- **Dependencies.**
  - AIStor charts from `https://helm.min.io/` and a customer license. The Free license covers single-node deployments only, allows commercial use, and forbids redistribution, so GroundX ships no license.
  - MinIO's upgrade procedure installs with `--take-ownership` and points to Helm 3.17 or later for ownership errors.
  - S4 is installed from its git tag `v0.3.2` (`charts/s4`); the pinned image is a single `linux/amd64` build.
- **Validation.** `.build/bin/validate-helm.sh` run with helm v3.19.0 (`GX_ON_PREM_HELM`) must pass with no snapshot change; `helm template` of the pinned AIStor and S4 charts with the new values files; a byte comparison of each mirrored file; and the MinIO closure grep against the allowlist recorded in this change's design.md.
- **Out of scope here (unchanged).** Chart templates and defaults, the `minio` storage-type name, rejecting unknown storage types, data-copy tooling, new CI jobs, a highly available store, and the bucket-wide public-read policy.
- **Open design questions.** None. The restore image and the minimum-version wording were decided at the GX-88 plan gate on 2026-10-14 (engineering-context `openspec/changes/gx-88-migrate-minio-to-s4/design.md`, Decisions).
