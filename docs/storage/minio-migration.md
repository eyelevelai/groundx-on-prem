# MinIO Migration and Recovery

Run commands from the repository root. For a new store, follow [AIStor installation](../../README.md#deploying-a-dedicated-aistor-object-store). For S4, use the [S4 migration guide](s4.md#migrating-from-minio-or-aistor).

## Object Keys That Start with a Slash

This applies only to a store connected as `serviceType: minio` that keeps a leading `/` in object keys, such as an S3-compatible store other than MinIO or AIStor. MinIO and AIStor drop the leading `/` when they store an object, so their keys need no change, and AWS S3 (`serviceType: s3`) is not affected.

GroundX 0.2.7 services wrote some keys with a leading `/`. In chart 0.2.8, the `groundx`, `upload`, `pre-process`, `process`, `queue`, and `summary-client` services remove the leading `/` from every key and prefix, so on a store that kept the slash they no longer find those objects. Before upgrading GroundX to chart 0.2.8, stop uploads and wait until no documents are still processing, so that 0.2.7 services write no new keys. Then list the keys that start with `/`, rename each one without it, and upgrade GroundX straight after the rename. These commands use the AWS CLI, which works against S3-compatible stores.

```bash
export AWS_ACCESS_KEY_ID=<store-access-key> AWS_SECRET_ACCESS_KEY=<store-secret-key>
STORE=<store-url>
BUCKET=eyelevel

aws s3api list-objects-v2 --endpoint-url "$STORE" --bucket "$BUCKET" \
  --prefix / --query 'Contents[].[Key]' --output text > slash-keys.txt
```

If `slash-keys.txt` is empty or holds only `None`, there is nothing to rename. Otherwise copy each object to its key without the slash, compare sizes, and delete the original only when they match. Compare sizes with `head-object`, as the loop does: S4's listing can show an object it has just copied as 0 bytes.

```bash
while IFS= read -r key; do
  [ "$key" = None ] && continue
  new="${key#/}"
  aws s3api copy-object --endpoint-url "$STORE" --bucket "$BUCKET" \
    --copy-source "$BUCKET/$key" --key "$new" > /dev/null || break
  old_size="$(aws s3api head-object --endpoint-url "$STORE" --bucket "$BUCKET" --key "$key" --query ContentLength)"
  new_size="$(aws s3api head-object --endpoint-url "$STORE" --bucket "$BUCKET" --key "$new" --query ContentLength)"
  [ "$old_size" = "$new_size" ] || { echo "size mismatch: $key"; break; }
  aws s3api delete-object --endpoint-url "$STORE" --bucket "$BUCKET" --key "$key"
done < slash-keys.txt
```

`copy-object` copies at most 5 GB per object, so the loop stops (`|| break`) at a larger object. Copy that object to its key without the slash using a tool that copies in parts, such as `aws s3 cp`, compare sizes, and delete the original. Then keep `slash-keys.txt` under another name, run the listing again, and run the loop on the new list; keep every list for a rollback, where an object over 5 GB needs the same tool.

After the upgrade, before you resume uploads, keep `slash-keys.txt` under another name and run the listing again in the same shell. Any key it finds was written by a 0.2.7 service before the upgrade finished: rename it with the same loop, and keep every list for a rollback.

To roll back to chart 0.2.7, reverse the rename once for each key in the lists you kept: copy each key without the slash back to its `/` form, compare sizes, and delete the copy without the slash. A key can appear in more than one list; reverse it only once. Objects those services wrote on chart 0.2.8 are stored without the slash and are not in any list, so 0.2.7 services may not find them.

## Upgrading an Existing MinIO Install to AIStor

These steps move a community MinIO tenant installed by earlier versions of the [installation guide](../../README.md) (operator release `minio-operator` and tenant release `minio-cluster`, both in `eyelevel`) to AIStor on the same disk. GroundX tested them with chart 7.1.1 of both releases; `helm list -n eyelevel` shows your versions. MinIO's guide is tested against operator charts 6.x and 7.x and refers earlier versions to MinIO support. The steps follow MinIO's [upgrade guide](https://docs.min.io/aistor/administration/upgrade-aistor-server/open-source-minio/kubernetes/), with the changes GroundX's tests needed. The store keeps its name, hosts, and credentials, so GroundX needs no setting change.

MinIO states that the upgrade is permanent and cannot be reversed. The first step therefore snapshots the tenant's disk, which [Restoring Community MinIO from the Pre-Upgrade Snapshot](#restoring-community-minio-from-the-pre-upgrade-snapshot) uses to go back. Before you start:

- Use Helm 3.17 or later (`helm version`), as MinIO's guide requires.
- Have your AIStor license ready (see [Deploying a Dedicated AIStor Object Store](../../README.md#deploying-a-dedicated-aistor-object-store)). A tenant with more than one server needs a paid license; the Free license covers one server.
- The `VolumeSnapshot` step needs a CSI snapshot controller and a `VolumeSnapshotClass` for your storage driver. GroundX's bundled EKS Terraform installs neither. On EKS that means the snapshot controller add-on and a `VolumeSnapshotClass` for the EBS CSI driver, which GroundX has not verified. Without CSI snapshot support, snapshot the disk with your provider's tools instead.
- Docker, to run MinIO's migration tool.

1. Stop uploads to GroundX, then wait until no documents are still processing. Processing keeps writing files to MinIO, and anything written after the snapshot is not in it. Uploads stay stopped until step 8. GroundX has not tested this wait. Then record the tenant's volume claim name, StorageClass, and size, which a restore needs, and snapshot the claim. With the 0.2.7 sample values the tenant has one claim, `data0-minio-tenant-minio-tenant-pool-0-0`; `kubectl -n eyelevel get pvc` lists yours. `kubectl get volumesnapshotclass` lists the snapshot classes.

   ```bash
   kubectl -n eyelevel get pvc data0-minio-tenant-minio-tenant-pool-0-0 \
     -o jsonpath='{.spec.storageClassName}{" "}{.spec.resources.requests.storage}{"\n"}'

   cat <<'EOF' | kubectl apply -f -
   apiVersion: snapshot.storage.k8s.io/v1
   kind: VolumeSnapshot
   metadata:
     name: minio-pre-aistor
     namespace: eyelevel
   spec:
     volumeSnapshotClassName: <snapshot-class>
     source:
       persistentVolumeClaimName: data0-minio-tenant-minio-tenant-pool-0-0
   EOF
   kubectl -n eyelevel wait --for=jsonpath='{.status.readyToUse}'=true \
     volumesnapshot/minio-pre-aistor --timeout=10m
   ```

2. Install the AIStor operator with your license. Add the AIStor repository as in the first block of [Deploying a Dedicated AIStor Object Store](../../README.md#deploying-a-dedicated-aistor-object-store), then run:

   ```bash
   kubectl create namespace aistor
   kubectl -n aistor create secret generic minio-license \
     --from-file=minio.license=<path-to-your-license-file>

   helm install aistor-operator \
     minio/aistor-operator \
     --version 6.0.0 \
     -n aistor \
     --take-ownership \
     -f helm/values/aistor/values.operator.yaml
   ```

   `--take-ownership` lets the AIStor operator take over CRD `policybindings.sts.min.io`, which the community operator also installed.

3. Back up the tenant. MinIO's guide appends the Secrets to the Tenant file, which then no longer reads back as a Tenant, so these commands write the tenant's Secret to a separate file. They also save both community releases' values, which a restore needs, and print the image the tenant runs; write it down.

   ```bash
   kubectl -n eyelevel get tenant minio-tenant -o yaml > tenant-backup.yaml
   kubectl -n eyelevel get secret myminio-env-configuration -o yaml > tenant-secrets-backup.yaml
   helm get values minio-cluster -n eyelevel -o yaml > minio-cluster-values.yaml
   helm get values minio-operator -n eyelevel -o yaml > minio-operator-values.yaml
   kubectl -n eyelevel get tenant minio-tenant -o jsonpath='{.spec.image}{"\n"}'
   ```

   Keep these files somewhere safe. `tenant-secrets-backup.yaml` holds the tenant's credentials Secret, and `minio-cluster-values.yaml` holds the store's root credentials.

4. Generate the AIStor object store values with MinIO's migration tool, pinned to the image MinIO's `latest` tag pointed to when GroundX tested the upgrade. The tool runs in a container and reads only the kubeconfig mounted into it, so the first command writes one with the current context's credentials inline. The server address in that file must be reachable from inside the container.

   ```bash
   kubectl config view --flatten --minify > aistor-migration-kubeconfig
   ```

   On EKS, a kubeconfig written by `aws eks update-kubeconfig` logs in through the `aws eks get-token` exec plugin, which the container cannot run (`It looks like you are trying to use a client-go credential plugin that is not installed`). Replace that login in the file with a token, using yq v4; if you ran `aws eks update-kubeconfig` with `--profile` or `--role-arn`, pass the same option to `aws eks get-token`. The token expires after 15 minutes, so run the tool straight after:

   ```bash
   yq -i ".users[0].user = {\"token\": \"$(aws eks get-token --cluster-name <cluster-name> --region <region> --query status.token --output text)\"}" aistor-migration-kubeconfig
   ```

   On minikube, set the file's server to the minikube node address (`https://<minikube-ip>:8443`) and add `--network <minikube-profile>` to the `docker run` below. Keep the file for step 9; it holds your cluster credentials, so delete it if you skip step 9. Then generate the values:

   ```bash
   docker run --rm \
     -v "$PWD/aistor-migration-kubeconfig:/root/.kube/config:ro" \
     quay.io/minio/aistor/operator-migration:RELEASE.2026-05-06T15-08-11Z@sha256:4ac3380d75aa92ca3c03454af2362a649ce4ddee866c962044e4b6e6d118b957 \
     generate-helm --namespace eyelevel > aistor-objectstore-values.yaml
   ```

5. Move the credentials to a Secret the object store can keep. The tool writes the tenant's credentials into the generated file, and the AIStor chart refuses the 0.2.7 sample pair `minio`/`minio123`. Copy the tenant's `config.env` into a new Secret now: the old Secret, `myminio-env-configuration`, belongs to the tenant's Helm release and is deleted with it.

   ```bash
   kubectl -n eyelevel get secret myminio-env-configuration \
     -o jsonpath='{.data.config\.env}' | base64 -d \
     | kubectl -n eyelevel create secret generic minio-tenant-env-configuration \
       --from-file=config.env=/dev/stdin
   ```

   Then replace the `secrets` block of `aistor-objectstore-values.yaml` with:

   ```yaml
   secrets:
     name: minio-tenant-env-configuration
     existingSecret: true
   ```

   Review the rest of the generated file, including any `TODO` remarks the tool adds, and keep its pool name: it is what makes the object store reuse the existing volume claim. For a tenant installed from the 0.2.7 sample values, the result matches `helm/values/aistor/values.objectstore.upgrade.yaml`. Install from your generated file, which reflects your tenant; the example is only for comparison.

   Before you uninstall anything, check that the AIStor chart accepts the edited file. Stop unless this command succeeds:

   ```bash
   helm template minio-tenant minio/aistor-objectstore --version 1.1.0 -n eyelevel -f aistor-objectstore-values.yaml > /dev/null
   ```

   GroundX ran this check against `helm/values/aistor/values.objectstore.upgrade.yaml`, not during its upgrade test.

6. Uninstall the community tenant release. Storage is unavailable from here until the next step finishes; the volume claim stays.

   ```bash
   helm uninstall minio-cluster -n eyelevel
   ```

7. Install the AIStor object store:

   ```bash
   helm install minio-tenant \
     minio/aistor-objectstore \
     --version 1.1.0 \
     -n eyelevel \
     --take-ownership \
     -f aistor-objectstore-values.yaml
   ```

8. Confirm the upgrade, then resume uploads. `STATE` must read `Initialized` and `HEALTH` `green`:

   ```bash
   kubectl -n eyelevel get objectstore minio-tenant
   ```

9. Optional: remove the community operator. Run the migration tool's `protect-crds` first; uninstalling the community operator without it deletes CRD `policybindings.sts.min.io`, which AIStor now uses. The uninstall below runs only if `protect-crds` succeeds. It uses the `aistor-migration-kubeconfig` file from step 4. On EKS the token from step 4 has likely expired, so set a new one, as in step 4:

   ```bash
   yq -i ".users[0].user = {\"token\": \"$(aws eks get-token --cluster-name <cluster-name> --region <region> --query status.token --output text)\"}" aistor-migration-kubeconfig
   ```

   On minikube, add `--network <minikube-profile>` to the `docker run`, as in step 4. Then protect the CRD and uninstall:

   ```bash
   docker run --rm \
     -v "$PWD/aistor-migration-kubeconfig:/root/.kube/config:ro" \
     quay.io/minio/aistor/operator-migration:RELEASE.2026-05-06T15-08-11Z@sha256:4ac3380d75aa92ca3c03454af2362a649ce4ddee866c962044e4b6e6d118b957 \
     protect-crds --namespace eyelevel --release minio-operator \
     && helm uninstall minio-operator -n eyelevel
   rm aistor-migration-kubeconfig
   ```

## Restoring Community MinIO from the Pre-Upgrade Snapshot

These steps go back from AIStor to community MinIO using the `VolumeSnapshot` taken in step 1 of the upgrade. Objects written after the snapshot are lost, including everything written while the store ran on AIStor. The restore does not touch GroundX's database or search index, so documents ingested after the snapshot stay listed in GroundX without their files, X-Ray and page images, and must be re-ingested. This consequence follows from where GroundX keeps its data and was not tested. The tested restore starts with the community operator removed; other starting points were not tested. The steps reinstall chart 7.1.1; restoring a tenant that ran another chart version was not tested. You need Helm 3.17 or later, the files saved in the upgrade's backup step, and the claim name, StorageClass, and size recorded in its first step.

First confirm that the snapshot is ready to restore from. This must print `true`. If it prints anything else, stop: step 4 deletes the AIStor-era volume claim and replaces it with one created from this snapshot.

```bash
kubectl -n eyelevel get volumesnapshot minio-pre-aistor -o jsonpath='{.status.readyToUse}'
```

If you snapshotted the disk with your provider's tools instead of a `VolumeSnapshot`, this check and step 4 do not apply: restore the disk with your provider's own restore steps, which GroundX has not tested.

Then stop uploads to GroundX and wait until no documents are still processing, because GroundX cannot write files while storage is down in steps 1 to 7. GroundX has not tested this wait.

1. Uninstall the AIStor object store. Storage is unavailable until step 7.

   ```bash
   helm uninstall minio-tenant -n eyelevel
   ```

2. Delete the ServiceAccount `minio-tenant-sa` that AIStor leaves behind. This step is required: the community operator reuses an existing ServiceAccount with that name, and with the one AIStor left, the tenant pod did not start (`Init:CrashLoopBackOff` in GroundX's test).

   ```bash
   kubectl -n eyelevel delete serviceaccount minio-tenant-sa
   ```

3. Recommended: delete the other objects AIStor leaves in `eyelevel`. The `minio-license` Secret there is the AIStor operator's copy of your license Secret.

   ```bash
   kubectl -n eyelevel delete rolebinding minio-tenant-eyelevel-binding
   kubectl -n eyelevel delete secret minio-tenant-generated minio-license minio-tenant-env-configuration
   ```

4. Replace the AIStor-era volume claim with one restored from the snapshot, using the claim name, StorageClass, and size you recorded. Do not wait for the new claim to bind: GroundX's StorageClass binds a claim only when a pod uses it, which happens when the tenant starts in step 6.

   ```bash
   kubectl -n eyelevel delete pvc data0-minio-tenant-minio-tenant-pool-0-0

   cat <<'EOF' | kubectl apply -f -
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: data0-minio-tenant-minio-tenant-pool-0-0
     namespace: eyelevel
   spec:
     storageClassName: <recorded-storage-class>
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: <recorded-size>
     dataSource:
       apiGroup: snapshot.storage.k8s.io
       kind: VolumeSnapshot
       name: minio-pre-aistor
   EOF
   ```

5. Reinstall the community operator 7.1.1 with the operator values you saved. `--take-ownership` is required: the AIStor operator now owns CRD `policybindings.sts.min.io`, and a plain install fails with an ownership error. GroundX's test passed the 0.2.7 sample operator values file directly; installing from the saved `minio-operator-values.yaml`, which for an install from the 0.2.7 guide holds the same values, was not tested.

   ```bash
   helm repo add minio-operator https://operator.min.io/
   helm repo update

   helm install minio-operator \
     minio-operator/operator \
     --version 7.1.1 \
     -n eyelevel \
     --take-ownership \
     -f minio-operator-values.yaml
   ```

6. Install the community tenant 7.1.1 as release `minio-cluster` with the tenant values you saved and a server image you can pull. As of 2026-10-14 the default server image of tenant chart 7.1.1 no longer downloads anonymously. Chart 7.1.1 builds the image reference from `tenant.image.repository` followed by `tenant.image.digest`, or by `tenant.image.tag` when no digest is set.

   If you have no copy of your own, use the image GroundX tested, `ghcr.io/coollabsio/minio@sha256:69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9`. It is a third-party image of MinIO `RELEASE.2025-10-15T17-29-55Z`, published under `ghcr.io/coollabsio` and not by MinIO, so it is not an official MinIO image. It is also a newer server release than the chart's default, `quay.io/minio/minio:RELEASE.2025-04-08T15-41-24Z`. GroundX tested the restore only with a tenant that already ran this image; restoring a tenant that ran a different server release onto it was not tested. Set it as a repository ending in `@sha256` plus the digest:

   ```bash
   helm install minio-cluster \
     minio-operator/tenant \
     --version 7.1.1 \
     -n eyelevel \
     -f minio-cluster-values.yaml \
     --set tenant.image.repository=ghcr.io/coollabsio/minio@sha256 \
     --set tenant.image.digest=69b55a1c1c5dc285ce04db96689f5b2102317fc77a50680a1874ca6efd1c87f9
   ```

   If you keep a copy of the image the tenant ran (recorded in the backup step) in your own registry, set it as repository and tag instead, and clear the digest so a digest left in the saved values does not win over the tag. GroundX did not test this form.

   ```bash
   helm install minio-cluster \
     minio-operator/tenant \
     --version 7.1.1 \
     -n eyelevel \
     -f minio-cluster-values.yaml \
     --set tenant.image.repository=<your-registry>/<image> \
     --set tenant.image.tag=<tag> \
     --set tenant.image.digest=
   ```

7. Confirm the restore, then resume uploads. `STATE` must read `Initialized` and `HEALTH` `green`. The tenant serves the same hosts with the credentials from the saved values, so GroundX needs no setting change.

   ```bash
   kubectl -n eyelevel get tenant minio-tenant
   ```

8. Optional: uninstall the AIStor operator. In GroundX's test the tenant stayed healthy, and Helm kept the AIStor CRDs. It leaves Secret `minio-license`, your license, in namespace `aistor`; deleting that Secret was not tested.

   ```bash
   helm uninstall aistor-operator -n aistor
   ```

## Staying on Community MinIO

You can keep an existing community MinIO tenant, and its GroundX settings do not change, but it receives no fixes: MinIO archived the community server and operator repositories. As of 2026-10-14 the default server image of tenant chart 7.1.1, `quay.io/minio/minio:RELEASE.2025-04-08T15-41-24Z`, no longer downloads anonymously, so a tenant pod rescheduled to a node that does not already hold the image may not start. Keep a copy of the server image your tenant runs in your own registry, and point the tenant's image at that copy. This prints the image the tenant runs:

```bash
kubectl -n eyelevel get tenant minio-tenant -o jsonpath='{.spec.image}{"\n"}'
```

