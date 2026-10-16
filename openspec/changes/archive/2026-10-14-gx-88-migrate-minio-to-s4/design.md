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
   - Amended 2026-10-14 after the restore spike: the operator also copies the license into the object store's namespace, as Secrets `minio-license` and `minio-tenant-generated` in `eyelevel`. Neither has an owner, so both outlive `helm uninstall` of the object store. Evidence (workspace GX-88 evidence `restore-spike/`): `04-upgrade.sh` creates `minio-license` only in `aistor`, and `logs/07-restore-corrected.log` step R3 still finds `minio-tenant-generated` (created by the operator with the object store, no owner) and deletes `minio-license` from `eyelevel`. The log records the Secrets, not their contents; that both hold the license comes from the spike review, not from the log. The restore recommends deleting both (decision 9).
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
   - fsGroup: the image runs as UID 1001 (`docker/Dockerfile:106` at `797911cb`; registry config `User: 1001`, `architecture: amd64`, read 2026-10-14). The chart sets no fsGroup (`charts/s4/values.yaml:202-204`), although its README table lists a default of `0` (`charts/s4/README.md:167`). `1001` avoids the root group. As of 2026-10-15 no test had shown that the volume is writable with this `fsGroup`: GX-88 minikube test M6, which installs S4 from the README, had not run. Amended 2026-10-16: M6 and M6x installed S4 from the README with this `fsGroup` on minikube and wrote to and read from the volume (workspace GX-88 evidence `local-l3-minikube/`).
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
   - Amended 2026-10-14 after the restore spike (evidence paths below are in the workspace GX-88 evidence `restore-spike/`):
     - **Separate backup files.** The Tenant and the Secrets go to two files, each written with `>`. MinIO's guide appends the Secrets to the Tenant file with `>>` (the guide's backup step). That file holds two top-level mappings with no document separator, so it parses as one document with duplicate keys: yq v4.53.2 returns `List` for `.kind`, so a read that selects the Tenant by kind (`select(.kind=="Tenant")`) returns nothing. Reproduced 2026-10-14 with a Tenant followed by a `kubectl get secrets -o yaml` list; the spike's own select-by-kind read of its combined backup returned an empty image (`logs/03-backup-snapshot.log`).
     - **Records the restore needs.** Before anything changes, the backup records the tenant's claim name, its StorageClass and size, and the Tenant's `.spec.image`, and saves both community releases' values: `helm get values minio-cluster -n eyelevel -o yaml` and `helm get values minio-operator -n eyelevel -o yaml`. The README warns that the tenant values file holds the root credentials. The spike saved and reused the tenant values (`03-backup-snapshot.sh`, `07-restore-corrected.sh` step R8); it passed the 0.2.7 operator values file directly instead of saved operator values, so the saved operator values are untested (decision 9).
     - **A kubeconfig the migration tool can use inside its container.** `operator-migration` runs in a container and reads only the kubeconfig mounted into it, so the README writes one with `kubectl config view --flatten --minify` (current context only, certificates inline), and its server address must be reachable from inside the container. Only the minikube form ran: the flattened file with its server rewritten to the minikube node address and the container on the minikube network (`04-upgrade.sh`). On EKS, a kubeconfig that logs in through the `aws eks get-token` exec plugin likely fails inside the container; this is not verified here and is checked in EKS test E6.
     - **Snapshot prerequisites.** The `VolumeSnapshot` step needs a snapshot controller and a `VolumeSnapshotClass` for the cluster's CSI driver. GroundX's bundled EKS Terraform installs neither: `git grep -i snapshot -- terraform/aws` at `07d332fc` finds only the node groups' root-volume `snapshot_id` settings (`terraform/aws/eks/eks.tf:249`). The README names the prerequisite (on EKS, the snapshot-controller add-on and a `VolumeSnapshotClass` for the EBS CSI driver) and says the EKS specifics are not verified here. The spike used minikube's `volumesnapshots` and `csi-hostpath-driver` add-ons (`00-cluster.sh`).
   - Amended 2026-10-15 (review fix): before the community tenant is uninstalled, the README renders the edited values with `helm template minio-tenant minio/aistor-objectstore --version 1.1.0 -n eyelevel -f aistor-objectstore-values.yaml > /dev/null` and tells the reader to stop unless it succeeds. This check was not part of the tested upgrade run. On 2026-10-15, with helm v3.19.0, it exited 0 for `values/aistor/values.objectstore.upgrade.yaml` and 1 for the same file with the chart's refused `minio`/`minio123` pair added, and for malformed YAML.
   - Amended 2026-10-15 (review fix, round 2): the README no longer follows the order the Linear body gave at planning (2026-10-14), snapshot then stop uploads. Step 1 now stops uploads, waits until no documents are still processing, and only then records the claim and takes the snapshot, so writes from uploads and processing no longer fall between the snapshot and the stop. The former step 2 is folded into step 1, the later steps move up by one, and uploads resume at the confirm step (now step 8). The wait is derived from how GroundX writes processing results and was not tested.
   - Amended 2026-10-15 (review fix, round 3): this change's proposal, its spec delta for the upgrade requirement, and task 3.2's text now give the same order as the README: stop uploads and wait, then the snapshot. Task 3.2's check also requires the README's `Stop uploads to GroundX, then wait` line to come before the section's first `kind: VolumeSnapshot` line.
   - Amended 2026-10-15 (review fix, round 4): task 3.2's check now anchors the snapshot on the first `kind: VolumeSnapshot` line, not on the first line that mentions VolumeSnapshot (the prerequisites bullet), so a snapshot moved after `helm uninstall` fails it.

9. **Snapshot and restore.**
   - The snapshot is a Kubernetes `VolumeSnapshot` of the tenant's volume claim (prerequisites in decision 8). Clusters without CSI snapshot support use their provider's disk snapshot, and the README says so.
   - Restore removes the AIStor object store release and its claim, creates a claim with the same name from the snapshot (`dataSource`), and reinstalls the community operator and tenant charts 7.1.1 from `https://operator.min.io/` with the saved values.
   - The tenant image is the customer's own registry copy of the image the tenant ran (recorded in the backup) when they have one. Otherwise it is `ghcr.io/coollabsio/minio@sha256:69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9` (plan-gate decision, workspace design 2026-10-14).
   - Amended 2026-10-14: the snapshot-restore spike held. Evidence paths are in the workspace GX-88 evidence `restore-spike/`. The ordered working sequence is `07-restore-corrected.sh`, run 2 on minikube with Helm v3.19.0 (`logs/07-restore-corrected.log`). After the restore, after a pod restart, and after removing the AIStor operator, all 24 data checks passed: every seeded object's content, ETag and tags, the bucket policy, anonymous read, both markers written after the snapshot absent, and a new write. A control that created the claim without the snapshot failed 22 of 24 (`run1/logs/06-control.log`). The README writes these steps, in this order:
     1. `helm uninstall minio-tenant -n eyelevel` removes the AIStor object store.
     2. **Required:** delete ServiceAccount `minio-tenant-sa` before installing the community tenant. AIStor leaves it behind with no owner (`logs/07-restore-corrected.log` step R3). Community operator 7.1.1 names the tenant's ServiceAccount `<tenant>-sa` and reuses an existing one by name without changing it, and the pod template does not set token automounting, so the ServiceAccount decides whether the token is mounted (`pkg/apis/minio.min.io/v2/helper.go:376`, `pkg/controller/service-account.go:29-42`, `pkg/resources/statefulsets/minio-statefulset.go:660` at minio/operator `v7.1.1`, `6eee6a7c`). With the AIStor ServiceAccount still there, the tenant pod stayed in `Init:CrashLoopBackOff` (`run1/logs/05b-restore-R4.log` step R7). Once that tenant release was uninstalled the ServiceAccount was gone as well, and reinstalling the tenant on the same restored claim, with the other AIStor leftovers still in place, gave a new ServiceAccount, `Initialized`, and all 24 checks passing (`run1/logs/05c-fix-forward.log`). The finer cause, AIStor setting `automountServiceAccountToken: false` so that the `validate-arguments` init container (`minio-statefulset.go:708`) has no token, comes from the spike review; the logs do not capture the init container's output, and step R3's query prints `n/a` for both false and unset.
     3. Recommended cleanup: RoleBinding `minio-tenant-eyelevel-binding`, Secrets `minio-tenant-generated` and `minio-license` (license copies, decision 3), and `minio-tenant-env-configuration`. Run 1 never deleted them and passed once the ServiceAccount was gone; run 2 deleted them all and passed.
     4. Delete the AIStor-era claim, then create a claim with the name the tenant's volume claim template expects (`data0-minio-tenant-minio-tenant-pool-0-0` for the 0.2.7 sample values), `dataSource` the `VolumeSnapshot`, and the StorageClass and size recorded before the upgrade (decision 8). The snapshot outlived its source claim (step R5). The README does not tell readers to wait for the claim to bind: GroundX's StorageClass binds only when a pod uses the claim (`volumeBindingMode: WaitForFirstConsumer`, `src/groundx/prereqs/storageclass/templates/storageclass.yaml:9`). The spike's wait for `Bound` worked only because minikube's `csi-hostpath-sc` binds immediately (`logs/00-cluster.log`).
     5. Reinstall community operator 7.1.1 as release `minio-operator` with `--take-ownership` and the saved operator values. The AIStor release owns CRD `policybindings.sts.min.io` after the upgrade, so a plain install fails with an ownership error and leaves no release (`run1/logs/05b-restore-R4.log` step R6); with `--take-ownership` it installs and takes the CRD back (step R6b, and run 2 step R7). The restore therefore also needs Helm 3.17 or later, the release MinIO's guide requires for the flag (decision 8).
     6. Install community tenant 7.1.1 as release `minio-cluster` with the saved tenant values and an image override. Chart 7.1.1 builds the image as `repository:digest`, falling back to the tag (`helm/tenant/templates/tenant.yaml:22` at minio/operator `v7.1.1`). The mirror is therefore set as `tenant.image.repository=ghcr.io/coollabsio/minio@sha256` plus `tenant.image.digest=69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9`, as the spike ran it (step R8), and the README also states the full reference `ghcr.io/coollabsio/minio@sha256:69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9`. A customer's own registry copy is set as repository plus tag, which was not tested here, and the README says so. The same template line means a digest left in the saved values wins over the tag, so that form also clears `tenant.image.digest`.
     7. Confirm the tenant reports `Initialized` and health `green`.
     8. Optional: uninstall the AIStor operator. Tested safe (step R11): the tenant stayed `Initialized` and green and passed all 24 checks; `policybindings.sts.min.io` stayed with `minio-operator`, and Helm kept the AIStor CRDs under their resource policy. It leaves Secret `minio-license` in `aistor`, which `kubectl` created; deleting that Secret was not tested.
   - Deviations from the tested run, each named in the README: the operator values come from the saved `helm get values minio-operator` file, where the spike passed the 0.2.7 sample file (`values/minio/values.operator.yaml` at `07d332fc`, deleted by task 5.1) directly; the registry-copy image form; and no wait for the claim to bind. `helm get values` prints the values supplied at install, which the spike showed for the tenant release (`logs/03-backup-snapshot.log`), so for an install from the 0.2.7 README the saved operator values are that file's content.
   - Amended 2026-10-15 (review fix):
     - Before step 1, the README checks that `VolumeSnapshot` `minio-pre-aistor` reports `readyToUse` `true` and tells the reader to stop otherwise, as the tested sequence read it at its step R1 (`07-restore-corrected.sh`; `logs/07-restore-corrected.log` prints `readyToUse=true`). A snapshot taken with a provider's tools needs that provider's own restore steps, which were not tested.
     - Step 6 discloses that the mirror is a third-party image of MinIO `RELEASE.2025-10-15T17-29-55Z` (its `org.opencontainers.image.version` and `org.opencontainers.image.source` labels, read from the image by digest on 2026-10-15), published under `ghcr.io/coollabsio` and not by MinIO. It is newer than the tenant chart 7.1.1 default, `quay.io/minio/minio:RELEASE.2025-04-08T15-41-24Z` (`helm/tenant/values.yaml:31-33` at minio/operator `v7.1.1`). The spike's tenant already ran the mirror before the upgrade (`logs/03-backup-snapshot.log`), so a restore of a tenant that ran another server release was not tested.
   - Amended 2026-10-15 (review fix, round 2): before restore step 1, the README stops uploads and waits until no documents are still processing, and step 7 resumes uploads. The restore intro says that documents ingested after the snapshot stay listed in GroundX without their files, X-Ray and page images and must be re-ingested, because the restore does not touch GroundX's database or search index. Both are derived, not tested. The restore step numbers are unchanged.
   - Amended 2026-10-15 (review fix, round 3): the restore requirement, in this change's spec delta and in the main spec, now names that pre-step (stop uploads and wait) before uninstalling the object store, and requires the README to state that documents ingested after the snapshot stay listed without their files and must be re-ingested.
   - Amended 2026-10-15 (review fix, round 4): task 3.3's text now names that pre-step (after the `readyToUse` check, stop uploads and wait until no documents are still processing, before any uninstall) and the re-ingest note, both marked derived and not tested. Task 3.3's check also requires the README's `Then stop uploads to GroundX and wait` line to come before the restore section's first `helm uninstall minio-tenant`, and the section to contain `re-ingested`.

10. **Object keys with a leading slash.**
    - The section applies to stores connected as `serviceType: minio` that keep a leading `/`. Keys written that way by 0.2.7 services are unreachable once 0.2.8 services trim the slash.
    - MinIO and AIStor store such writes without the slash, so their keys are unaffected (the MinIO-family leading-slash entry of the external-semantics list the user approved at the plan gate, workspace `design.md` Decisions, 2026-10-14).
    - The README lists keys under prefix `/` with the AWS CLI (`s3api list-objects-v2 --endpoint-url ...`), then copies each to the trimmed key, compares sizes, and deletes the original. The AWS CLI works against any S3-compatible store.
    - Rolling back to chart 0.2.7 reverses the rename.
    - Amended 2026-10-15 (review fix): the README stops uploads and waits for processing to finish before the listing, upgrades GroundX straight after the rename, and runs the listing again after the upgrade, keeping both lists for a rollback. This follows from when 0.2.7 services write keys; like the rest of the section, it was not tested then (the listing, the loop, the over-5 GB branch, and the rollback ran on 2026-10-15 and 2026-10-16, below).
    - Amended 2026-10-15 (review fix, round 3): `s3api copy-object` copies at most 5 GB per object (`awscli/botocore/data/s3/2006-03-01/service-2.json`, the CopyObject documentation, at aws-cli tag `2.35.15`), so the rename loop stops at a larger object. The README tells the reader to copy that object with a tool that copies in parts, such as `aws s3 cp`, compare sizes, delete the original, list again and run the loop on the new list, and notes the same limit for a rollback. Because a stopped run can leave more than two lists, the README now keeps every list and reverses each key once across them on a rollback, instead of "both lists". This is derived from the AWS CLI documentation; see the 2026-10-16 amendment for the test.
    - Amended 2026-10-16 (local tests, workspace GX-88 evidence `local-c9-cashbot-go/` and `local-c9b-slash-large-rollback/`): the listing and the loop ran as written against S4, which keeps the slash; GroundX's updated Go storage client read every key after the rename and none before it. With a 5.5 GiB object the loop stopped at it, `aws s3 cp` copied it in parts, and a second listing and loop finished. The rollback reverse rename, written from the README's prose, restored every key unchanged, the large one through `aws s3 cp`. A key can sit in more than one kept list, so the README says to reverse it once. The README states these results and no longer calls the section untested.

11. **S4 README content.** Each limit the README states has a source:
    - one replica: `charts/s4/values.yaml:4` at `797911cb`;
    - object count per bucket: `docs/operations/faq.md:366` at `797911cb`;
    - amd64 only: registry config, decision 6;
    - health checks only on the web UI port: `templates/deployment.yaml:70-71,78-79`;
    - the 5 GiB large-file limit: the cashbot-go `s4` reader refuses more than 5 GiB without uploading (cashbot-go `openspec/changes/archive/2026-10-14-gx-88-migrate-minio-to-s4/design.md`, decision 4: "Refusing before the upload gives a clear error instead of a failed request after up to 5 GiB has been sent."), the single-PUT ceiling in minio-go v7.0.100 `constants.go:39`;
    - the file-name length limit: the S4 name-limit entry of the external-semantics list the user approved at the plan gate (workspace `design.md` Decisions, 2026-10-14); amended 2026-10-16: replaced by GX-88 test C7's measurements (single upload 207 bytes stored, 208 refused; multipart 172 and 173; 3-byte UTF-8 names 66 and 54 bytes stored), workspace GX-88 evidence `local-c7/`.

    Credential-rotation behavior is stated only if GX-88 test C7 confirms it. Amended 2026-10-16: C7 confirmed it (a restart with new credentials refuses them and keeps the first-start keys), and the README lists it as a limit.

    Migration:
    - Copy every object with the same keys using `rclone`, the tool the research copy used.
    - Then set the public-read policy for `s3:GetObject` on `arn:aws:s3:::<bucket>/*`. ai-server sets this policy only when it creates the bucket (`document/upload_minio.py:86-105` at ai-server `d7a174d1`), so a bucket created for the copy needs it set by hand.
    - Object tags are not copied.
    - Cutback deletes Service `minio`, installs the store release again from its saved values on the kept volume claim, and restores the previous `file` settings (amended 2026-10-16; it first pointed `file.existing` back at an unchanged MinIO store).
    - Amended 2026-10-15 (review fix), with evidence in the workspace GX-88 evidence `s4-readme-copy/` and `c2-cashbot-go/`:
      - The README's copy commands (the six rclone environment-variable remotes, `rclone mkdir`, `rclone copy --metadata`, the policy step, and `rclone check`) ran as written against S4 0.3.2 in local containers on 2026-10-15, and the README says so. The S4 `helm install` had not run on a cluster then; amended 2026-10-16: it ran on minikube, see below.
      - `rclone check src:eyelevel dst:eyelevel` runs before the switch. It exits 1 whenever a file name is too long for S4, so the reader switches only if every reported difference is such a name. It compares objects MinIO stored in parts by size only.
      - The first step waits for processing to finish before the copy. This is derived, not tested. (A fallback that re-ran the copy just before the switch was removed on 2026-10-16, below.)
    - Amended 2026-10-16 (cross-family review, two P1 findings):
      - GroundX saves each file's full URL, including the store's host, on the document and inside processed files (cashbot-go `pkg/processor/post.go:169`, `pkg/processor/cached.go:268-277`), and `Copier.CopyTraining` refuses a URL that does not start with the configured base (`pkg/copy/copy.go:389-393`). Connecting S4 at `s4.eyelevel.svc.cluster.local:7480` therefore broke every document stored before the move. The migration now keeps MinIO's URL: after the copy it uninstalls the MinIO store release (its volume claim stays), creates Service `minio` sending port 80 to S4's port 7480 (selector of S4 release `s4`), and connects GroundX with `serviceType: s4` and `url: http://minio.eyelevel.svc.cluster.local`. With those values every storage URL the chart renders for cashbot-go, layout, and extract is byte-identical to the default install's; only the startup wait moves from `minio-tenant-hl:9000` to `minio:80`. It covers a store installed by this guide with `file.existing.url`, `file.customDomain`, and `file.serviceName` unset (the chart builds the default host from `file.serviceName`); any other store must keep its exact scheme, host, and port, untested. Step 7 also ingests a test document, because the link check does not use GroundX's S4 keys.
      - The fallback that re-ran the copy just before the switch is removed: a write after the final check would still be missing from S4. Uploads stay stopped and processing finished through the copy, the check, and the switch; if that cannot be confirmed, the reader does not migrate.
      - Cutback installs the store release again from its saved values on the kept volume claim.
      - Tested on minikube on 2026-10-15 and 2026-10-16 (workspace GX-88 evidence `local-l3-minikube/`), from a community MinIO tenant and from an AIStor object store, without GroundX installed: the S4 install and steps 2 to 5 ran as written; afterwards GroundX's Go storage client, configured as step 6 sets it, opened and copied files stored before the move, while the same client at `s4...:7480` failed with `copyTraining not internal URL`; going back restored each store on its kept claim. The layout and extract storage clients were not run through the switch. Step 5 now takes the release name as `<store-release>`, says GroundX cannot read stored files until step 6 finishes, and the way back names the chart version to reinstall.
      - One more limit: write-once holds only for writers that do not overlap in time. Eight concurrent conditional single PUTs to one new key gave two successes in 3 of 40 rounds, with one writer's content kept.

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
    - The checks prove that the files say and render what the specs require. They do not prove the runbooks work on a cluster. Running the documented commands on a store is left to the GX-88 container, minikube, and validation EKS tests in the workspace test plan. As of 2026-10-15, minikube tests M6 (the README's S4 install and its copy from MinIO) and M7 (any air-gapped steps) had not run. Amended 2026-10-16: M1, M4, M5, M6 and M6x ran on minikube (workspace GX-88 evidence `local-l3-minikube/`); M7 had not.

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

**Section level.** The legacy install markers are `operator.min.io`, `minio-operator/operator`, `minio-operator/tenant`, `values/minio/`, and `quay.io/minio/minio:`. In `README.md` they may appear only from `#### Upgrading an Existing MinIO Install to AIStor` to the next `### ` heading. Elsewhere they may appear only in `bin/operator`, `terraform/groundx-operator/**`, `*/values/chainguard/**`, and the OpenSpec records (`openspec/changes/**`, `openspec/specs/**`), which quote the markers to state this rule. `values/minio/` may not appear anywhere outside those OpenSpec records and out-of-scope files, the README included. Amended 2026-10-15 (review fix): archiving this change created `openspec/specs/object-store-install-and-upgrade/spec.md`, which quotes the markers, so tasks 5.1 and 7.2 now exclude `openspec/specs/**` as well; task 7.1 still allows only this change's two specs there.

The closure checks are tasks 7.1 (file level) and 7.2 (section level). Task 7.2 first runs its scan on a counterexample, which must fail, and on the upgrade and restore shape, which must pass, before scanning the repo.

## Risks / Trade-offs

- [Customers need an AIStor license; Free covers one server and allows no redistribution] → The README makes the license an explicit install step and states what happens without it. S4 is documented as the license-free option, and staying on MinIO is documented with its risk.
- [The restore names a third-party mirror image] → It is used only when the customer has no copy of their own, it is pinned by digest, and it is the image GroundX tested (plan-gate decision).
- [The snapshot is taken before uploads stop (the Linear body's order), so objects written between the snapshot and the stop are not in it] → The restore section states that anything written after the snapshot is lost. The snapshot exists to roll back a failed upgrade, not to capture the last writes.
  - Amended 2026-10-15 (review fix, round 2): uploads now stop and processing finishes before the snapshot (decision 8), so writes from uploads and processing no longer fall in this gap. This is derived, not tested. Objects written after the snapshot are still lost on a restore (decision 9).
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
   - Chart: back to 0.2.7. An install on `s4` must first go back to MinIO or AIStor (S4 below), and a slash-key rename must be reversed.
   - AIStor upgrade: restore the snapshot into a community MinIO tenant.
   - S4: delete Service `minio`, install the store release again from its saved values on the kept volume claim, and restore the previous `file` settings.

## Open Questions

None. The snapshot-restore spike held on 2026-10-14, and decision 9 records the commands it fixed.
