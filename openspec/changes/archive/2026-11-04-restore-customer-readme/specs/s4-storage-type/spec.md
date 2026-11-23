## MODIFIED Requirements

### Requirement: The README documents S4 next to AWS S3

`README.md` SHALL contain `#### Using S4` immediately after `#### Using AWS S3`, listed in the table of contents. The README section SHALL briefly state that S4 is experimental and has no high availability, point production installs to AIStor and link `docs/storage/s4.md#installation`. The linked guide SHALL install S4 by cloning tag `v0.3.2` and installing `charts/s4` with `helm/values/s4/values.yaml`; connect GroundX with `file.existing.url: http://<s4-service>.<namespace>.svc.cluster.local:7480` and `serviceType: s4`; state that S4 always uses region `us-east-1`; state chart 0.2.8 as the minimum GroundX version; list S4's limits (one replica, the 5 GiB large-file limit, the file-name length limit, the object count per bucket, amd64 only, and health checks that cover only the web UI port); state next to the 5 GiB limit that in S4 mode, large-file import and review (large-file delivery, off by default) spool each upload to a temporary file in the pod's `TMPDIR` on top of the copy the importer already keeps, so they need temporary pod disk of about twice the largest file for each upload in flight (cashbot-go `openspec/changes/archive/2026-10-14-gx-88-migrate-minio-to-s4/design.md`, decision 5: "In S4 mode the spool is a second copy, so the worker needs about twice the file's size in temporary disk, up to 5 GiB per upload in flight."); point production installs to the AIStor section; and link to `docs/storage/s4.md#limits` for detailed limits and `docs/storage/s4.md#migrating-from-minio-or-aistor` for migration. The guide SHALL describe migration from MinIO as: stop uploads and wait until no documents are still processing, keep uploads stopped through the switch, and do not migrate if that cannot be confirmed; copy every object with the same keys (with `rclone`); set the public-read policy for `s3:GetObject`; then keep MinIO's storage URL by handing Service `minio` (port 80 to S4's port 7480) to S4 and connecting GroundX with `serviceType: s4` and `url: http://minio.eyelevel.svc.cluster.local`, because GroundX saves each file's full URL, including the store's host, and reads and copies only files whose URL starts with its storage URL (cashbot-go `pkg/processor/cached.go`, `pkg/copy/copy.go` `CopyTraining`); noting that object tags are not copied, plus the cutback that installs the MinIO store release again on its kept volume claim.

#### Scenario: S4 entry links its installation guide (finalize success)
- **WHEN** the README headings and S4 entry are read
- **THEN** `#### Using S4` directly follows `#### Using AWS S3`
- **AND** the entry states that S4 is experimental, has no high availability, points production installations to AIStor and links `docs/storage/s4.md#installation`
- **AND** the README limits the linked inline-credential and anonymous-read procedures to `fileAccess.enabled: false`.

#### Scenario: Detailed S4 instructions remain in the guide (finalize success)
- **WHEN** `docs/storage/s4.md` is read
- **THEN** it contains `serviceType: s4`, `helm/values/s4/values.yaml`, `--branch v0.3.2`, `:7480`, `us-east-1`, `0.2.8`, `5 GiB`, `temporary pod disk of about twice` and `do not migrate`
- **AND** it links the AIStor installation, limits and migration sections
- **AND** it preserves `rclone`, `s3:GetObject`, object tags, `url: http://minio.eyelevel.svc.cluster.local` and the cutback procedure
- **AND** it warns that protected buckets must stay private.
