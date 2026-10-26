# Storage Documentation Evidence

Source: the storage section of `README.md` at commit `496efc711a6acb5ba7911ac194dab35169e1b14b`. These are historical observations, not new deployment results. Current procedures live in `docs/storage/s4.md` and `docs/storage/minio-migration.md`.

## S4 0.3.2

Fresh installation ran on minikube on 2026-10-15 and 2026-10-16, and on EKS on 2026-10-16 in a namespace other than `eyelevel`.

Single uploads stored keys up to 246 URL-encoded bytes; multipart uploads stored keys up to 210 bytes. Longer keys were refused. After a restart with changed credentials, S4 refused the new keys (`InvalidAccessKeyId`) and continued accepting the original ones. With eight simultaneous writers creating one new key, two writers both reported success in 3 of 40 rounds, while only one writer's content survived.

Migration from both community MinIO and AIStor ran on minikube on 2026-10-15 and 2026-10-16. Migration from community MinIO also ran on EKS on 2026-10-16 outside namespace `eyelevel`. The copy, bucket policy, copy check, and Service handover ran as written. Files stored before the move opened and copied through S4 at MinIO's URL. On EKS, a new document was ingested, searched, and extracted. Layout and extract storage clients also read and wrote through a stand-in for Service `minio` in local containers. Community MinIO migration interrupted storage for a few seconds. Cutback recovered the kept volume claim and its data after about 13 seconds on minikube and 25 seconds on EKS.

## Leading-slash keys

The rename commands ran against S4 on 2026-10-15 and 2026-10-16 (UTC). Before the rename, the updated Go storage client could not read slash-prefixed keys; afterward, every key read back unchanged. A 5.5 GiB object stopped the single-copy loop, was copied in parts with `aws s3 cp`, and a second listing and loop completed the rename. The reverse rename, including the large object copied in parts, restored every object's content.

## AIStor

The in-place upgrade interrupted storage for about 24 seconds on EKS and one minute on minikube. Migration-tool value generation ran on both. The snapshot restore ran on minikube on 2026-10-14, starting with the community operator removed; other starting points were not tested.

The fresh-install operator settings disabled the cluster-wide pod webhook and automatic certificate approval; installation and upgrade worked with both disabled. Without the license Secret, no store started. Creating the Secret in `aistor` let the store start about one minute later without reinstalling.

The pinned charts were `aistor-operator` 6.0.0 and `aistor-objectstore` 1.1.0; newer charts were published on 2026-10-14. The [AIStor Free agreement](https://www.min.io/legal/aistor-free-agreement) was read on 2026-10-13; the [community upgrade guide](https://docs.min.io/aistor/administration/upgrade-aistor-server/open-source-minio/kubernetes/) was read on 2026-10-14. These dates record the source checks, not current vendor terms.
