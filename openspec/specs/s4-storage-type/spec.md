# s4-storage-type Specification

## Purpose
TBD - created by archiving change gx-88-migrate-minio-to-s4. Update Purpose after archive.
## Requirements
### Requirement: S4 sample values pin the tested release and keep S4 inside the cluster

`src/groundx/values/s4/values.yaml` and its byte-identical copy `helm/values/s4/values.yaml` SHALL configure the S4 chart (`charts/s4` at git tag `v0.3.2`, commit `797911cbaa1b44fcaecfdfe69145a6a904ef7463`, of `https://github.com/rh-aiservices-bu/s4`) with `image.tag: "0.3.2@sha256:48d1875da2eb087f6b52e01f3e97daa750962a347132230c27d35878c48ce16f"`, `image.pullPolicy: IfNotPresent`, `route.enabled: false`, `service.type: ClusterIP`, a pod `securityContext.fsGroup`, `nodeSelector.node: eyelevel-cpu-only`, and S3 and web UI credentials that replace the chart defaults. Validated by `helm lint` and `helm template` (helm v3.19.0) of the cloned chart, reading named fields only.

#### Scenario: S4 values render the pinned, cluster-internal deployment (finalize success)
- **GIVEN** the S4 chart at `v0.3.2` and `values/s4/values.yaml`
- **WHEN** `helm lint` and `helm template` run
- **THEN** lint passes and the `Deployment` image is `quay.io/rh-aiservices-bu/s4:0.3.2@sha256:48d1875da2eb087f6b52e01f3e97daa750962a347132230c27d35878c48ce16f` with `imagePullPolicy: IfNotPresent`
- **AND** no object has an `apiVersion` in `route.openshift.io`
- **AND** the pod `securityContext.fsGroup` is set and `nodeSelector.node` is `eyelevel-cpu-only`
- **AND** every `Service` is `ClusterIP`
- **AND** the readiness probe is `GET /api` on port 5000, the web UI port, which is the limit the README states for S4 health checks

#### Scenario: Chart default credentials are not rendered (reject before state)
- **WHEN** the same render's chart `Secret` is read
- **THEN** `AWS_ACCESS_KEY_ID` is not `s4admin`, `AWS_SECRET_ACCESS_KEY` is not `s4secret`, and `UI_USERNAME` and `UI_PASSWORD` are set

#### Scenario: Credentials from an existing Secret (finalize success)
- **GIVEN** the same values with `s3.existingSecret=s4-credentials`
- **WHEN** `helm template` runs
- **THEN** the chart renders no `Secret` and the container's `envFrom` reads Secret `s4-credentials`, which therefore must hold `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `UI_USERNAME`, and `UI_PASSWORD`

#### Scenario: S4 values are byte-identical in both chart trees (finalize success)
- **WHEN** `cmp` compares the two copies
- **THEN** the files are identical

### Requirement: The chart documents `s4` as a storage type without changing any default

The `file.existing.serviceType` comment at `src/groundx/values.yaml:74` and `helm/values.yaml:74` SHALL list `s4` with `minio` and `s3`. The parsed content of both `values.yaml` files SHALL equal the base commit's, so no default changes. No chart template changes: the chart already passes `file.existing.serviceType` through unchanged to cashbot-go (`upload.service`), the ai-server layout workers (`uploadType`), and the extract services (`type`), and keeps the bucket in the path for every value other than `s3`.

#### Scenario: Comment lists s4 and defaults stay the same (finalize success)
- **WHEN** both `values.yaml` files are read
- **THEN** each `# serviceType:` comment line names `s4`
- **AND** `yq -o=json` of each file equals `yq -o=json` of the same file at the merge base with `origin/main`

#### Scenario: s4 reaches every consumer unchanged (finalize success)
- **GIVEN** `file.existing.url=http://s4.eyelevel.svc.cluster.local:7480`, `file.existing.serviceType=s4`, no region, and `extract.enabled=true`
- **WHEN** the chart renders in `mode` `all` and `ingest`
- **THEN** the cashbot-go config has `service: s4`, the layout config has `uploadType="s4"` and `uploadURL="http://s4.eyelevel.svc.cluster.local:7480/eyelevel/"`, and the extract config has `type="s4"`
- **AND** storage wait init containers run `nc -z s4.eyelevel.svc.cluster.local 7480`
- **AND** nothing in the render contains `amazonaws`

### Requirement: The README documents S4 next to AWS S3

`README.md` SHALL contain `#### Using S4` immediately after `#### Using AWS S3`, listed in the table of contents. The section SHALL install S4 by cloning tag `v0.3.2` and installing `charts/s4` with `helm/values/s4/values.yaml`; connect GroundX with `file.existing.url: http://<s4-service>.<namespace>.svc.cluster.local:7480` and `serviceType: s4`; state that S4 always uses region `us-east-1`; state chart 0.2.8 as the minimum GroundX version; list S4's limits (one replica, the 5 GiB large-file limit, the file-name length limit, the object count per bucket, amd64 only, and health checks that cover only the web UI port); state next to the 5 GiB limit that in S4 mode, large-file import and review (large-file delivery, off by default) spool each upload to a temporary file in the pod's `TMPDIR` on top of the copy the importer already keeps, so they need temporary pod disk of about twice the largest file for each upload in flight (cashbot-go GX-88 design decision 5 at `b87a3706c`); point production installs to the AIStor section; and describe migration from MinIO as copying every object with the same keys (with `rclone`) and then setting the public-read policy for `s3:GetObject`, noting that object tags are not copied, plus the cutback to the unchanged MinIO store.

#### Scenario: S4 section sits next to AWS S3 with its limits (finalize success)
- **WHEN** the README's level-3 and level-4 headings are listed
- **THEN** `#### Using S4` directly follows `#### Using AWS S3`
- **AND** the section contains `serviceType: s4`, `helm/values/s4/values.yaml`, `--branch v0.3.2`, `:7480`, `us-east-1`, `0.2.8`, `5 GiB`, `temporary pod disk of about twice`, `rclone`, `s3:GetObject`, `tags`, and a link to `#deploying-a-dedicated-aistor-object-store`

### Requirement: Chart version 0.2.8 is the minimum for s4

`version` and `appVersion` in `src/groundx/Chart.yaml` and `helm/Chart.yaml` SHALL be `0.2.8`, so default image tags select the service releases that implement `s4`. Templates, defaults, and snapshots SHALL NOT change. `openspec/config.yaml` SHALL NOT hard-code the chart version.

#### Scenario: Version bump changes nothing but the version (finalize success)
- **GIVEN** both `Chart.yaml` files at `0.2.8`
- **WHEN** the base commit's chart, with this change's `Chart.yaml` copied in, and this change's chart are rendered with the same inputs listed under the object-store capability's "Existing installs render the same objects" scenario
- **THEN** every pair is byte-identical
- **AND** `.build/bin/validate-helm.sh` run with helm v3.19.0 passes
- **AND** no file under `src/groundx/tests/__snapshot__/` differs from the merge base or is untracked
- **AND** `openspec/config.yaml` no longer contains `Chart version: 0.2.7`

