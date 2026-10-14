## Goals / Non-Goals

The motivation and blast radius are in `proposal.md`; this file records how the change is built.

**Goals:**
- AIStor sample values and README steps that give a new install a working store under the customer's license, with the hosts the chart already uses.
- An in-place upgrade, a restore path, and a documented "stay on MinIO" option for installs on the community MinIO tenant.
- `s4` documented as a storage type, with an S4 values file, its limits, and a copy migration.
- Chart 0.2.8, so default image tags pick up the service releases that implement `s4`.
- No community-MinIO install text left outside the upgrade and restore sections and the unchanged out-of-scope files.

**Non-Goals:**
- Any chart template, default, `values.schema.json`, or snapshot change.
- The Chainguard MinIO seeds, `terraform/groundx-operator/**`, `bin/operator`, data-copy tooling, a new CI job, a highly available store, the bucket-wide public-read policy, trace capture, and Bedrock on non-AWS stores.

## Decisions

**Invariant.** After this change, a reader who follows any document in this repo to install a store is pointed at AIStor or S4, never at community MinIO; community-MinIO install text exists only where it is needed to leave MinIO (the README upgrade and restore steps), in the "staying on MinIO" section, and in the unchanged out-of-scope files. The sweep is judged against this meaning, not against the string `minio`. AIStor's own identifiers (`minio-tenant`, `minio-license`, `quay.io/minio/aistor/...`), the `minio` storage type, and the `minio-tenant-hl` host all contain the string and are correct.

1. **Values file layout.** New files live in both `src/groundx/values/` and `helm/values/`, byte-identical:
   - `aistor/values.operator.yaml`
   - `aistor/values.objectstore.yaml` (fresh install)
   - `aistor/values.objectstore.upgrade.yaml` (upgrade example)
   - `s4/values.yaml`

   `values/minio/` is deleted from both trees. The names follow `values/percona/values.{operator,cluster}.yaml`. The values files carry no comments; the README explains them.

2. **Operator values.** The file sets three keys:
   - `global.operator.nodeSelector.node: eyelevel-cpu-only`
   - `global.operator.optOutAutomaticCertificates: true`
   - `operators.object-store.webhook.enabled: false`

   Sources in `aistor-operator` 6.0.0: `values.yaml:114` (node selector under `global.operator`), `:129` (opt-out), `:218` (webhook), and `templates/cluster-role-binding-certificate-management.yaml:7,12` (the certificate-approval binding renders unless opted out).

   The operator Deployment takes its selector from `global.operator.nodeSelector` or a per-operator override (`templates/deployment-operator.yaml:73`); the chart reads no top-level `nodeSelector`. So the check asserts the selector on the rendered `Deployment`s, not on the key.

   The check also renders the chart without the file (1 webhook configuration, 5 bindings) next to the render with it (0 and 2). This shows that the values, not the chart defaults, remove both.

3. **Namespaces and the license.**
   - The operator is installed as release `aistor-operator` in namespace `aistor`.
   - The license is Secret `minio-license`, key `minio.license`, in `aistor`. The operator reads the license from its own release namespace (`aistor-operator` 6.0.0 `templates/NOTES.txt:31`, `templates/secret-license.yaml:5-6,21`). By default it watches every namespace (`values.yaml:116-118`).
   - The object store is installed as release `minio-tenant` in the GroundX namespace `eyelevel`. The chart's default hosts are `minio.<namespace>` and `minio-tenant-hl.<namespace>` (`src/groundx/templates/_helpers/services/file.tpl:144`).
   - `aistor` matches MinIO's upgrade guide, which installs the operator there (https://docs.min.io/aistor/administration/upgrade-aistor-server/open-source-minio/kubernetes/, read 2026-10-14).
   - Alternative: install the operator in `eyelevel` like the README's other operators. The cluster-wide operator would still find the store, but the README would diverge from MinIO's guide and troubleshooting docs, which assume `aistor`.

4. **Object-store credentials come from an existing Secret.**
   - Both object-store files set `secrets.name: minio-tenant-env-configuration` and `secrets.existingSecret: true`.
   - For a fresh install, the README creates that Secret with key `config.env` holding `export MINIO_ROOT_USER=...` and `export MINIO_ROOT_PASSWORD=...`, the format the chart expects (`aistor-objectstore` 1.1.0 `values.yaml:28-41`), and tells the reader to set GroundX `file.username`/`file.password` to the same values.
   - Why: the chart refuses `minio`/`minio123` when it creates the Secret itself (`templates/object-store-configuration.yaml:3,12`). Keeping credentials out of values files also keeps them out of the Helm release record.
   - Alternative: let the chart create the Secret from `secrets.accessKey`/`secretKey` in values or `--set`. Rejected because the credentials would be stored in the release.

5. **Fresh install and upgrade example differ in pool name only.**
   - Fresh: one pool `pool-0` (the chart's own pool name, `aistor-objectstore` 1.1.0 `values.yaml:112`), one server, one `20Gi` volume, requests `100m`/`256Mi`, the node selector, and TLS off.
   - Upgrade example: the shape `operator-migration generate-helm` produced for a tenant installed from the 0.2.7 sample values. That is pool `minio-tenant-pool-0`, one server, one `20Gi` volume, and the same requests, with its `secrets` block replaced as in decision 4.
   - The pool name must match the old tenant's. With it kept, the tested upgrade came back on the same disk with every file intact (in-place upgrade entry of the external-semantics list the user approved at the plan gate, workspace `design.md` Decisions, 2026-10-14); a different pool name is untested and would not name the existing volume claim.
   - The Secret name must differ from `myminio-env-configuration`. The old tenant's Helm release owns that Secret and deletes it on uninstall.
   - The README tells upgraders to keep their generated file and replace only its `secrets` block with the example's. The example is for comparison; it is not a substitute for the generated file.

6. **S4 values.**
   - Overrides of chart defaults (chart at `v0.3.2`, commit `797911cb`):
     - `image.tag` pinned with its digest (default `latest`, `charts/s4/values.yaml:12`);
     - `pullPolicy: IfNotPresent` (default `Always`, `:14`);
     - `route.enabled: false` (default `true`, `:166`);
     - placeholder S3 and UI credentials that the README says to replace (defaults `s4admin`/`s4secret`, `:32,34`; UI credentials are required by `templates/secret.yaml:18-19`).
   - Also set:
     - `service.type: ClusterIP`, explicit although it is the default (`:111`);
     - `podSecurityContext` with `runAsNonRoot: true` and `fsGroup: 1001`;
     - `nodeSelector.node: eyelevel-cpu-only`, like every other store in this repo.
   - fsGroup: the image runs as UID 1001 (`docker/Dockerfile:106` at `797911cb`; registry config `User: 1001`, `architecture: amd64`, read 2026-10-14). The chart sets no fsGroup (`charts/s4/values.yaml:202-204`), although its README table lists a default of `0` (`charts/s4/README.md:167`). `1001` avoids the root group. GX-88 test M6 proves the volume is writable.
   - The README documents `s3.existingSecret` as the alternative and lists all four keys that Secret must hold. With it, the chart renders no Secret at all (`templates/secret.yaml:1`).

7. **README structure.** Headings and their order are fixed because the task checks and the harness mirror read them:
   - `### MinIO AIStor` replaces `### MinIO`. Under it, in order:
     1. "Using an existing store" (wording free; covers `serviceType: minio`)
     2. `#### Using AWS S3` (kept)
     3. `#### Using S4`
     4. `#### Deploying a Dedicated AIStor Object Store`
     5. `#### Object Keys That Start with a Slash`
     6. `#### Upgrading an Existing MinIO Install to AIStor`
     7. `#### Restoring Community MinIO from the Pre-Upgrade Snapshot`
     8. `#### Staying on Community MinIO`
   - The table of contents lists each section.
   - The fresh-install section's first `bash` block starts with `helm repo add minio https://helm.min.io/`, and that line appears nowhere else in the README.
     - groundx-studio-harness scanner check 9 compares the code block around the first match of its marker (`scripts/scans/scan-on-prem.mjs:1394-1405` at `465a58d1a`). A unique first line, in the first block of the AIStor sections, gives the harness change a stable marker.
     - The upgrade section refers back to that block for the repository step instead of repeating it.
   - The README pins `aistor-operator` `--version 6.0.0` and `aistor-objectstore` `--version 1.1.0`, the versions tested. The AIStor repository published 6.1.0 and 1.2.0 on 2026-10-14 (workspace plan decision).

8. **Upgrade steps.**
   - The section follows the order the Linear body gives and MinIO's guide (URL in decision 3). It states, from the guide, that the upgrade is permanent and cannot be reversed, and that Helm 3.17 or later is required.
   - The operator and the object store are installed with `--take-ownership`.
   - `protect-crds` runs before `helm uninstall` of the community operator (release `minio-operator` in `eyelevel`, per the 0.2.7 README). Uninstalling the old release without it deletes the shared `policybindings.sts.min.io` CRD (same guide).
   - The 0.2.7 README installed the tenant as release `minio-cluster` in `eyelevel`; the commands use these names.
   - `operator-migration` is pinned to `quay.io/minio/aistor/operator-migration:RELEASE.2026-05-06T15-08-11Z@sha256:4ac3380d75aa92ca3c03454af2362a649ce4ddee866c962044e4b6e6d118b957`. MinIO's guide uses `:latest` with `--pull=always`.
     - Quay's tag API (`https://quay.io/api/v1/repository/minio/aistor/operator-migration/tag/?specificTag=latest&onlyActiveTags=false`, read 2026-10-14) shows one `latest` entry, last moved 2026-05-06, at that manifest-list digest, so `:latest` resolved to this image during the 2026-10-13 upgrade tests.
     - Pinning keeps the generated values matched to the pinned chart versions. A newer tool needs a new test run before the pin moves.
   - The backup step saves the tenant resource and Secrets, as the guide does. It also saves the tenant release's values with `helm get values minio-cluster`, because the restore needs them and the 0.2.7 sample files no longer ship. The README says these files hold credentials and must be stored safely.

9. **Snapshot and restore.**
   - The snapshot is a Kubernetes `VolumeSnapshot` of the tenant's volume claim. Clusters without CSI snapshot support use their provider's disk snapshot, and the README says so.
   - Restore removes the AIStor object store release and its claim, creates a claim with the same name from the snapshot (`dataSource`), and reinstalls the community operator and tenant charts 7.1.1 from `https://operator.min.io/` with the saved values.
   - The tenant image is the customer's own registry copy of the image the tenant ran (recorded in the backup) when they have one. Otherwise it is `ghcr.io/coollabsio/minio@sha256:69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9` (plan-gate decision, workspace design 2026-10-14).
   - The snapshot-restore assumption is spike-required (workspace contract, last external-semantics entry). Its outcome fixes the exact commands before this section is written. A falsified spike re-opens the plan rather than shipping untested steps.

10. **Object keys with a leading slash.**
    - The section applies to stores connected as `serviceType: minio` that keep a leading `/`. Keys written that way by 0.2.7 services are unreachable once 0.2.8 services trim the slash.
    - MinIO and AIStor store such writes without the slash, so their keys are unaffected (the MinIO-family leading-slash entry of the external-semantics list the user approved at the plan gate, workspace `design.md` Decisions, 2026-10-14).
    - The README lists keys under prefix `/` with the AWS CLI (`s3api list-objects-v2 --endpoint-url ...`), then copies each to the trimmed key, compares sizes, and deletes the original. The AWS CLI works against any S3-compatible store.
    - Rolling back to chart 0.2.7 reverses the rename.

11. **S4 README content.** Each limit the README states has a source:
    - one replica: `charts/s4/values.yaml:4` at `797911cb`;
    - object count per bucket: `docs/operations/faq.md:366` at `797911cb`;
    - amd64 only: registry config, decision 6;
    - health checks only on the web UI port: `templates/deployment.yaml:70-71,78-79`;
    - the 5 GiB large-file limit: the cashbot-go `s4` reader refuses more than 5 GiB without uploading (cashbot-go `openspec/changes/gx-88-migrate-minio-to-s4/specs/s4-object-storage/spec.md:45-47` at `b87a3706c`), the single-PUT ceiling in minio-go v7.0.100 `constants.go:39`;
    - the file-name length limit: the S4 name-limit entry of the external-semantics list the user approved at the plan gate (workspace `design.md` Decisions, 2026-10-14).

    Credential-rotation behavior is stated only if GX-88 test C7 confirms it.

    Migration:
    - Copy every object with the same keys using `rclone`, the tool the research copy used.
    - Then set the public-read policy for `s3:GetObject` on `arn:aws:s3:::<bucket>/*`. ai-server sets this policy only when it creates the bucket (`document/upload_minio.py:86-105` at ai-server `d7a174d1`), so a bucket created for the copy needs it set by hand.
    - Object tags are not copied.
    - Cutback points `file.existing` back at the unchanged MinIO store.

    The minimum GroundX version is chart 0.2.8 (plan-gate decision; explicitly pinned image tags are an accepted gap).

12. **Chart comment, defaults, and version.**
    - Only the comment at `values.yaml:74` changes, in both trees. The check compares the parsed YAML with the merge base, so no default can change unnoticed.
    - `version` and `appVersion` move to `0.2.8` in both `Chart.yaml` files. Snapshots are not expected to change: the snapshot suites pin `chart.appVersion: 0.1.0` (`src/groundx/tests/api_test.yaml:2-4`), and no snapshot contained `0.2.7` at `07d332fc` (checked 2026-10-14). Task 6.1 runs the full gate to confirm it.
    - `openspec/config.yaml` stops hard-coding the chart version and points at `src/groundx/Chart.yaml`, because the bump would make the current line false.
    - `service.yaml` `chart_version: 0.2.5` was already stale before this change and is left as it is.

13. **Store wording.**
    - `sample.values.yaml` gets store-neutral placeholders for `file.username`/`file.password`.
    - `values/README.md` lists `aistor` and `s4`.
    - `AGENTS.md`, `ARCHITECTURE_NOTES.md`, `service.yaml`, and `openspec/config.yaml` name MinIO AIStor, AWS S3, and S4, and the AIStor Helm repository.
    - `minio123` still ships in the unchanged Chainguard sample (`values/chainguard/values.yaml`), in `values.yaml` comments, and in test fixtures. So the "plaintext secret defaults" notes are reworded to point there, not deleted.

14. **Mirror check.** Each task check `cmp`s its file's two copies. `.build/bin/verify-storage-contract.py` `MIRRORED_FILES` is not extended.
    - That would change a guard whose `MIRRORED_FILES` branch had no test fixture at `07d332fc` (`.build/tests/test_verify_storage_contract.py` sets it to `()` in every case), for sample files.
    - The repo's other sample values (Percona, OpenSearch, Strimzi) are not guarded either.
    - Cost: later drift in these four files is not caught by CI.

15. **No ADR.** This `design.md`, archived with the change, is the in-repo record. The cross-repo decisions are in the workspace change folder.

16. **Contract classification, confirmed against the code.** Producer contract shapes confirmed; see `contract.md`.
    - Chart to cashbot-go, the ai-server layout workers, and the extract services: additive. The chart passes `file.existing.serviceType` through unchanged (`file.tpl:153-162`), and the task 2.2 render shows `s4` reaching all three with the bucket in the path.
    - README to the harness scanner: breaking for check 9's marker. This is handled by release order (harness after on-prem), as planned.
    - Deleting `values/minio/` breaks only scripts that pass those paths. This is accepted in the proposal.

17. **What the task checks prove.**
    - The checks are static. They render the pinned third-party charts and the GroundX chart, read named fields with `yq`, compare files, and search the README.
    - The render checks need helm v3.19.0 (via `GX_ON_PREM_HELM` or PATH) and fail closed on any other helm version; the third-party chart checks also need network access to `helm.min.io` or `github.com`.
    - Helm runs with a temporary `HELM_CACHE_HOME` and `HELM_REPOSITORY_CONFIG`, so no user cache or repository list is touched. Renders are never printed.
    - The chart-bump check runs `.build/bin/validate-helm.sh` with `helm` and `python` resolved to helm v3.19.0 and `python3` through a temporary PATH directory. The script calls bare `helm` and `python`, and the check proves the interpreter runs before trusting the gate.
    - The checks prove that the files say and render what the specs require. They do not prove the runbooks work on a cluster. The GX-88 container and minikube tests (C6, C7, C9, M1 to M7) and the validation EKS states execute the documented commands as written.

### MinIO sweep allowlist

Inventory point: `07d332fc` (44 files with `minio` in content). Excluded from the scan: `openspec/changes/**` (this change and the archive) and `src/groundx/tests/__snapshot__/**` (generated; must stay unchanged).

**File level.** After the change, a file whose path or content contains `minio` (case-insensitive) must be one of these:

| Files | Why it may contain `minio` |
|---|---|
| `README.md` | AIStor identifiers, the `minio` storage type, the upgrade, restore, and staying sections |
| `AGENTS.md`, `ARCHITECTURE_NOTES.md`, `service.yaml`, `openspec/config.yaml` | the product name "MinIO AIStor", generic "MinIO/S3" store-family wording, the Chainguard `minio123` note |
| `openspec/specs/object-store-install-and-upgrade/spec.md`, `openspec/specs/s4-storage-type/spec.md` | this change's specs after archive |
| `{src/groundx,helm}/values/aistor/values.objectstore.yaml`, `values.objectstore.upgrade.yaml` | object store name `minio-tenant` |
| `{src/groundx,helm}/values.yaml` | chart default store name and credentials comments, the `serviceType` comment |
| `{src/groundx,helm}/values/README.md` | "MinIO AIStor" |
| `{src/groundx,helm}/values/values.existing.yaml` | `serviceType: minio` example |
| `{src/groundx,helm}/templates/_helpers/services/file.tpl` | default service name and storage type |
| `{src/groundx,helm}/values/chainguard/values.yaml`, `values.minio.{operator,tenant}.yaml` | unchanged Chainguard seeds and their credentials |
| `src/groundx/tests/{extract_test,file_settings_test}.yaml`, `src/groundx/tests/files/values.{metadata,phoenix}.yaml` | storage-type value, `minio-tenant-hl` host, fixture credentials |
| `bin/operator`, `terraform/groundx-operator/**`, `terraform/shared/variables.tf` | out of scope; `variables.tf` is read only by the retired operator path |

`values/aistor/values.operator.yaml`, `values/s4/values.yaml`, and `sample.values.yaml` are deliberately absent. They must not contain `minio`.

**Section level.** The legacy install markers are `operator.min.io`, `minio-operator/operator`, `minio-operator/tenant`, `values/minio/`, and `quay.io/minio/minio:`. In `README.md` they may appear only from `#### Upgrading an Existing MinIO Install to AIStor` to the next `### ` heading. Elsewhere they may appear only in `bin/operator`, `terraform/groundx-operator/**`, and `*/values/chainguard/**`. `values/minio/` may not appear anywhere outside `openspec/changes/**` and those out-of-scope files, the README included.

The closure checks are tasks 7.1 (file level) and 7.2 (section level). Task 7.2 first runs its scan on a counterexample, which must fail, and on the upgrade and restore shape, which must pass, before scanning the repo.

## Risks / Trade-offs

- [Customers need an AIStor license; Free covers one server and allows no redistribution] → The README makes the license an explicit install step and states what happens without it. S4 is documented as the license-free option, and staying on MinIO is documented with its risk.
- [The restore names a third-party mirror image] → It is used only when the customer has no copy of their own, it is pinned by digest, and it is the image GroundX tested (plan-gate decision).
- [The snapshot is taken before uploads stop (the Linear body's order), so objects written between the snapshot and the stop are not in it] → The restore section states that anything written after the snapshot is lost. The snapshot exists to roll back a failed upgrade, not to capture the last writes.
- [S4 placeholder credentials left unchanged give a known login] → The README tells users to replace them or use `s3.existingSecret`. The S4 Service is `ClusterIP`, and the Route is off.
- [The pinned `operator-migration` image may miss MinIO's later fixes] → It is the image MinIO's `:latest` pointed to when the upgrade was tested. Moving the pin needs a new test run.
- [Harness scanner check 9 fails against this README until the harness change merges] → Release order: the harness merges after the chart is published.
- [`serviceType: s4` with images older than 0.2.8 sends files to AWS or fails extraction] → The docs state chart 0.2.8 as the minimum. Explicitly pinned image tags are an accepted gap (plan-gate decision).
- [Chart 0.2.8 rolls every default-tag workload onto 0.2.8 images] → The chart is published only after every default image exists at 0.2.8 (workspace release gates).
- [Task checks need network access and a specific helm version] → They fail closed and name the missing prerequisite. Renders run offline after the pull.

## Migration Plan

1. Merge after the workspace gates. A maintainer publishes chart 0.2.8 with `src/build.sh` once every default image exists at 0.2.8, the groundx-python release is out, and internal-arcadia-agents pins it.
2. Nothing changes for an existing install until its operator acts:
   - Store releases are separate Helm releases, so upgrading the GroundX chart does not touch them.
   - Installs on community MinIO choose between the in-place upgrade (snapshot first, one-way), staying on MinIO, or a copy to S4.
   - Stores connected as `serviceType: minio` that keep a leading `/` rename those keys before upgrading the GroundX chart.
3. Manual operator actions the README introduces: the AIStor license Secret, the object-store credentials Secret, the pre-upgrade snapshot and backup, and the S4 credentials and bucket policy.
4. Rollback:
   - Chart: back to 0.2.7. An install on `s4` must first point back at MinIO or AIStor, and a slash-key rename must be reversed.
   - AIStor upgrade: restore the snapshot into a community MinIO tenant.
   - S4: point `file.existing` back at the unchanged MinIO store.

## Open Questions

None. The restore commands wait on the snapshot-restore spike (decision 9).
