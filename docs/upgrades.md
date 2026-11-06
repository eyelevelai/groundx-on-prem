# Deployment and upgrade notes

Use these notes for storage and GPU configuration, or when upgrading an existing installation. Commands run from the repository root unless stated otherwise. Keep your customized values file and back up stateful services before upgrades.

Before a GroundX application upgrade, follow the [database migration requirements](agents/database-upgrades.md). Do not replace an existing values file with the new-install sample. To enable the file gateway on existing data, complete the [existing-file activation procedure](agents/private-file-access.md#upgrade-existing-files-before-activation).

- [Redis TLS upgrades](#redis-tls-upgrades)
- [OpenSearch installation and credentials](#opensearch)
- [Persistent storage](#persistent-storage)
- [Summary GPU sizing](#summary-gpu-sizing)
- [MinIO migration and recovery](storage/minio-migration.md)

## Redis TLS upgrades

Chart 0.2.8 images verify the certificate chain and the host name of a `rediss://` Redis in the layout, ranker and summary services, both the APIs and the workers. This applies when you set `ssl: true` under `cache.existing`, under the ranker-only `ranker.cache`, or under `cache.metrics.existing` for a separate metrics Redis; the certificate must cover the `addr` host name of each. A plain `redis://` Redis, including the Redis the chart installs, is unaffected. A certificate that chains to a public root needs no action.

If your Redis certificate comes from a private CA, or does not cover the `addr` host name, act before upgrading. Build a complete CA bundle from the public root CAs plus your private CA, store it in a Secret under the key `ca.crt` in the GroundX namespace (the `namespace` value, `eyelevel` by default), and set `fileAccess.caSecretName` to its name. If `fileAccess.caSecretName` is already set, for example for a private object-store CA, add the Redis CA to that Secret's `ca.crt` instead. Alternatively, correct `addr` to a host name the certificate covers.

The bundle replaces the container's default CA file. A Secret that holds only the private CA breaks the HTTPS calls that rely on public roots, such as an LLM API or an object store, so keep the public roots and any CAs already in the bundle.

If you skip this and a certificate does not verify, ingest, search and summary requests fail and the workers stop publishing and consuming tasks. The ai-server API and worker pods stay Ready even when they cannot connect, so after upgrading check the layout, ranker and summary logs for `certificate verify failed`.

The original chart 0.2.8 rollout verified the ai-server layout, ranker and summary clients. Its notes recorded that the extract client (AGE-395) and Workspace runner still accepted any certificate. Do not infer platform-wide verification from these results; check the extraction and Workspace images selected for your release.


## OpenSearch

### Installing OpenSearch

This install runs OpenSearch on certificates and an admin user that you supply. The seed values file (`helm/values/opensearch/values.yaml`) contains no certificate, key or password hash; do not put any in it.

Supply these inputs, issued by your own certificate authority:

- A CA certificate (`ca.crt`).
- A node certificate (`node.crt`) and its key (`node.key`), signed by that CA. The subject must be `CN=opensearch-node`, and the subject alternative names must include `opensearch-cluster-master.eyelevel.svc.cluster.local` (`<serviceName>-cluster-master.<namespace>.svc.cluster.local`, the host GroundX connects to). The certificate must be usable as both a server and a client certificate.
- An admin certificate and key signed by the same CA, with subject `CN=gx-opensearch-admin`. You keep these for administration; they are never mounted into the OpenSearch pod.
- The OpenSearch admin password as a bcrypt hash. Generate it with the image's own tool, which prompts for the password so it stays out of your shell history, and copy the printed hash:

```bash
docker run --rm -it --entrypoint plugins/opensearch-security/tools/hash.sh public.ecr.aws/c9r4x6y5/eyelevel/opensearch@sha256:8e95a30fe67dc3d92b85924e46cd299bc83fe2716e100bcad30e7e3a0b199b00
```

The plaintext of the same password must be provided to GroundX as `search.privilegedPassword` in your `values.yaml` or as `SEARCH_INIT_PASSWORD` in the cluster credentials Secret (the Secret route needs `groundx` and `process` images that read it; see [GroundX password delivery](#groundx-password-delivery)). Choose a password you have not published anywhere: the chart rejects a known published default for `search.password` or `search.privilegedPassword`.

Create the Secrets before OpenSearch starts, because the pod mounts both. Restrict permissions before each file exists, and create `internal_users.yml` in an editor rather than with a shell command so the hash is not saved to your shell history:

```bash
umask 077
```

Create `internal_users.yml` with this content, replacing the placeholder with the hash from above:

```yaml
_meta:
  type: "internalusers"
  config_version: 2
admin:
  hash: "<bcrypt-hash-of-the-admin-password>"
  reserved: true
  backend_roles:
    - "admin"
  description: "GroundX OpenSearch admin"
```

Then create the Secrets and delete the local `internal_users.yml`:

```bash
kubectl create secret generic opensearch-tls -n eyelevel --from-file=ca.crt --from-file=node.crt --from-file=node.key
kubectl create secret generic opensearch-internal-users -n eyelevel --from-file=internal_users.yml
rm internal_users.yml
```

GroundX trusts this OpenSearch through `fileAccess.caSecretName`: a Secret in the GroundX namespace whose `ca.crt` is a complete bundle, the public root CAs plus the CA that signed `node.crt` (see [the file-access operator contract](agents/private-file-access.md)). If `fileAccess.caSecretName` is already set, add this CA to that bundle. Otherwise start from a public root bundle, such as `/etc/ssl/certs/ca-certificates.crt` from your OS's Mozilla-derived bundle, append `ca.crt` to a copy of it named `ca-bundle.pem`, then create the Secret and set `fileAccess.caSecretName: groundx-ca-bundle` in your `values.yaml`:

```bash
kubectl create secret generic groundx-ca-bundle -n eyelevel --from-file=ca.crt=ca-bundle.pem
```

While GroundX uses this in-cluster OpenSearch, the chart will not render without a CA for it. To trust OpenSearch with its own CA instead of the bundle (`search.caSecretName`), see [Trusting OpenSearch with its own CA](#trusting-opensearch-with-its-own-ca).

Then install OpenSearch:

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm install opensearch opensearch/opensearch --version 2.23.1 -n eyelevel -f helm/values/opensearch/values.yaml
```

Keep `-f helm/values/opensearch/values.yaml` on every `helm upgrade opensearch …`, followed by `opensearch-overrides.yaml` if you changed any OpenSearch setting: without it, a changed `clusterName` or `nodeGroup` starts OpenSearch on a new, empty volume (see [Upgrading existing OpenSearch](#upgrading-existing-opensearch)). The values pin the tested OpenSearch image; to move to a newer image, test it and update the digest in that file.

To rotate certificates or fix a `request timed out` error from `groundx` or `process`, see [Rotating certificates](#rotating-certificates) and [Certificate errors](#certificate-errors).

The GroundX application user still has broad privileges, so also restrict network access to OpenSearch.

### GroundX password delivery

The chart has no default OpenSearch passwords. When `mode` is not `ingest`, set both: each search credential can be set through `values.yaml` (`search.password`, `search.privilegedPassword`) or through the cluster credentials Secret (`SEARCH_PASSWORD`, `SEARCH_INIT_PASSWORD` in `eyelevel-secret-credentials`), as the `MYSQL_*` keys do for `db`. The sample Secret in `src/groundx/prereqs/secret/values.yaml` carries both keys with empty values; fill them in.

The Secret route requires `cluster.secrets` to list `eyelevel-secret-credentials`, and `groundx` and `process` images that read `SEARCH_PASSWORD` and `SEARCH_INIT_PASSWORD`.

Both services log in to OpenSearch: the API (`groundx`) to search, and the indexing worker (`process`) to write documents to the index. Their default images are tagged with the chart's `appVersion`, and images up to 0.2.7 do not read these keys. Use compatible release images that read these keys, or set both passwords in values. If overriding images, select both `groundx.image` and `process.image` from a release containing cashbot-go#1809.

With an older `groundx` image the API has no search password and crash-loops; with an older `process` image the indexing worker cannot write to OpenSearch, so ingested documents fail.

Pods read the Secret only when they start, so after changing either key, restart both services.

Restart `groundx` first and wait for it, because it updates the `search.username` user to the new password at startup, then restart `process`: `kubectl rollout restart -n eyelevel deployment/groundx`, `kubectl rollout status -n eyelevel deployment/groundx`, then `kubectl rollout restart -n eyelevel deployment/process`.

Passwords delivered through the Secret are not render-validated by the chart, because the published-default check sees values only.

The Secret route applies to the direct-helm route; the Terraform operator still takes both passwords as values, required when `cluster.search` is `true` and not needed for an ingest-only install (`cluster.search = false`). In `mode: ingest` neither is used or rendered.

### Upgrading existing OpenSearch

Earlier versions of the README install left the OpenSearch image's demo security configuration in place. That configuration trusts a demo admin certificate whose private key is published in OpenSearch's public source, so any workload that can reach ports 9200 and 9300 could act as OpenSearch admin, whatever admin password was set. The GroundX chart also rejects a known published default for `search.password` or `search.privilegedPassword` and fails to render if you supply one, so an upgrade that silently keeps the old default (for example `helm upgrade --reuse-values`) will not deploy.

Moving an install from 2.19 or later to the pinned 3.2.0 is forward-only: OpenSearch cannot be downgraded on the same data, and `helm rollback` does not restore its earlier version or data, so take an OpenSearch snapshot to storage outside the cluster first if you can. An install below 2.19 keeps its OpenSearch version in this procedure.

Earlier chart versions defaulted both OpenSearch passwords to a public value, and the documented OpenSearch install trusted OpenSearch's demo certificates. An OpenSearch data volume created with them keeps its original admin password and stored users, because the seed values are only read on first initialization. Chart 0.2.8's default `groundx` and `process` images already verify certificates (cashbot-go #1865), so a 0.2.8 install on the demo-certificate OpenSearch is already failing with `request timed out` until you complete these steps. Before upgrading:

1. Check the OpenSearch version on every pod of your OpenSearch release. The label below uses the release name `opensearch` from the [README install](#installing-opensearch); for a release installed from the `groundx/opensearch` wrapper chart, use that release's name instead. If the command prints nothing, the label does not match your release: stop and correct it. `for p in $(kubectl get pods -n eyelevel -l app.kubernetes.io/instance=opensearch -o name); do kubectl exec -n eyelevel "$p" -- sh -c 'ls lib | grep "^opensearch-[0-9]"'; done`. The seed values pin OpenSearch 3.2.0 (`opensearch-3.2.0.jar`). OpenSearch upgrades to 3.x only from 2.19 or later and does not support downgrades, so what you do depends on the version every pod reports:
   - 2.19.0 to 3.2.0: upgrade with the commands below, which also move OpenSearch to 3.2.0.
   - Below 2.19 (possible on installs from earlier chart versions, which used the image's floating `latest` tag): re-certify without changing the version. Keep the image your pods run now in the overrides file described below, so the upgrade changes only the certificates. Read it from one of the pods the version check listed: `kubectl get <pod> -n eyelevel -o jsonpath='{.status.containerStatuses[?(@.name=="opensearch")].imageID}'` and put its registry, repository and digest into `global.dockerRegistry`, `image.repository` and `image.tag` (for example `tag: "latest@sha256:<digest>"`); `latest` alone now resolves to 3.2.0. Moving that install to 3.x is a separate upgrade through 2.19 later.
   - Above 3.2.0: stop and do not upgrade OpenSearch until that version has a tested path.

   Then create the `opensearch-tls` and `opensearch-internal-users` Secrets as described in [Installing OpenSearch](#installing-opensearch). Run `helm get values opensearch -n eyelevel` to see the settings your OpenSearch release uses, then upgrade it with one of these commands:
   - If those settings come only from the README values files and the install runs 2.19 or later, upgrade with the seed values file alone: `helm upgrade opensearch opensearch/opensearch --version 2.23.1 -n eyelevel -f helm/values/opensearch/values.yaml`.
   - If you changed any setting, first create `opensearch-overrides.yaml` holding only those settings (for example `clusterName`, `nodeGroup`, `persistence`, `replicas`, `resources` or `nodeSelector`) and leave out `config`, `extraEnvs`, `secretMounts`, `securityConfig`, `image` and `majorVersion`, which the seed values file now sets, except that an install below 2.19 keeps its `global.dockerRegistry` and `image` as described above. Then upgrade with both files: `helm upgrade opensearch opensearch/opensearch --version 2.23.1 -n eyelevel -f helm/values/opensearch/values.yaml -f opensearch-overrides.yaml`. Without the overrides file, a changed `clusterName` or `nodeGroup` makes Helm replace the StatefulSet and start OpenSearch on a new, empty volume while your data stays on the old one.

   - If you installed OpenSearch from the published `opensearch` wrapper chart (`groundx/opensearch`, version 0.1.1), upgrade that release with the wrapper chart instead of the commands above. Run `helm get values <release> -n eyelevel`. If you changed any setting, first create `opensearch-wrapper-overrides.yaml` holding only those settings under `operator:` (for example `operator.clusterName`, `operator.nodeGroup`, `operator.persistence`, `operator.replicas`, `operator.resources` or `operator.nodeSelector`) and leave out `config`, `extraEnvs`, `secretMounts`, `securityConfig`, `image` and `majorVersion`, which version 0.1.2 sets, except that an install below 2.19 keeps its `operator.global.dockerRegistry` and `operator.image` as described above. Then run `helm repo update` and `helm upgrade <release> groundx/opensearch --version 0.1.2 -n eyelevel -f opensearch-wrapper-overrides.yaml`, leaving out `-f opensearch-wrapper-overrides.yaml` if you changed nothing. Without the overrides file, a changed `clusterName` or `nodeGroup` starts OpenSearch on a new, empty volume, and an `extraEnvs` list in it replaces the one that turns the demo installer off. Create the two Secrets before the upgrade: without them the upgraded pod stays in `Init` with a "secret not found" mount error while Helm reports `deployed`. Version 0.1.2 keeps the StatefulSet name and volume claim of 0.1.1, so the release upgrades in place.

   The restart moves OpenSearch to your certificates and admin DN. The stored users, including the stored admin password, are unchanged.
2. Add the CA that signed `node.crt` to the `fileAccess.caSecretName` bundle, as described in [Installing OpenSearch](#installing-opensearch). Choose `groundx` and `process` images with certificate verification (cashbot-go #1865); step 7 deploys them. Do not deploy them before step 1: they reject the demo certificate, which OpenSearch serves until the step 1 upgrade restarts it.
3. Set `search.privilegedPassword` (or `SEARCH_INIT_PASSWORD`, which needs the `groundx` and `process` images described under [GroundX password delivery](#groundx-password-delivery)) to the admin password your OpenSearch currently uses, unless that is a published default. The chart rejects a published default supplied through values and will not render, so if your install still uses one, first rotate the OpenSearch admin password off it with the admin-password route in step 5, then set `search.privilegedPassword` to the new value.
4. Set `search.password` (or `SEARCH_PASSWORD`) to the application user password your install currently uses, unless that is a published default. The chart rejects a published default supplied through values, so if your install still uses one, choose a new application password for the upgrade. Make sure `search.privilegedPassword` already holds the correct admin password (from step 3 or the step 5 rotation) before changing `search.password`, or the GroundX API crash-loops when it re-creates `search.username`; confirm with the login check in step 5.
5. Rotate the credentials. The OpenSearch `admin` user is reserved, so the security REST API refuses to change it (it returns 403 "Resource 'admin' is reserved"). Use these routes instead:
   - Application password: set a new `search.password` (step 7 deploys it), or change `SEARCH_PASSWORD` in the Secret and restart `groundx` and then `process` as described under [GroundX password delivery](#groundx-password-delivery). The GroundX API re-creates `search.username` with it, using the admin credential, when its login is rejected.
   - Admin password: run the `securityadmin.sh` procedure in step 6, and in its substep 3 also put a new hash (from `plugins/opensearch-security/tools/hash.sh`, run without `-p` so it prompts for the password) in as the `admin` hash. The OpenSearch `admin` user is reserved, so the REST API cannot change it; authenticating with the operator admin certificate is the supported route.
   - Then set `search.privilegedPassword` to the new admin password; step 7 deploys it. Confirm the rotation from inside the pod with `curl --cacert config/certs/ca.crt -u admin https://opensearch-cluster-master.eyelevel.svc.cluster.local:9200/_plugins/_security/authinfo`, which prompts for the password: the new password must succeed and the old one must be rejected.

6. Remove the image's six demo users (required, whether or not you rotate the admin password). An OpenSearch data volume created from the image keeps every user the image shipped, and their password hashes are published. Authenticate `securityadmin.sh` with your operator admin certificate (`CN=gx-opensearch-admin`), which the upgraded OpenSearch trusts as its admin identity. Copy the admin certificate and key into the pod for the commands and remove them afterwards, for example `kubectl cp admin.crt eyelevel/opensearch-cluster-master-0:/tmp/admin.crt` and `kubectl cp admin.key eyelevel/opensearch-cluster-master-0:/tmp/admin.key`, then open a shell (`kubectl exec -it -n eyelevel opensearch-cluster-master-0 -- bash`) and run these steps. Start from a backup of the stored users, not the image's `internal_users.yml`, because uploading that file replaces the whole stored user list and would drop every user created through the REST API, including the GroundX application user, and break search.
   1. Back up the stored security configuration: `plugins/opensearch-security/tools/securityadmin.sh -backup /tmp/security-backup -icl -nhnv -cacert config/certs/ca.crt -cert /tmp/admin.crt -key /tmp/admin.key`.
   2. If you are also rotating the admin password, run `plugins/opensearch-security/tools/hash.sh` without `-p` so it prompts for the password and keeps it out of shell history.
   3. In `/tmp/security-backup/internal_users.yml`, delete the image's six demo users: `anomalyadmin`, `kibanaserver`, `kibanaro`, `logstash`, `readall` and `snapshotrestore`. Leave every other user unchanged, including `admin`, the GroundX application user (`search.username`) and any user you created. If you ran substep 2, put the printed hash as the `admin` hash.
   4. Upload only the users: `plugins/opensearch-security/tools/securityadmin.sh -f /tmp/security-backup/internal_users.yml -t internalusers -icl -nhnv -cacert config/certs/ca.crt -cert /tmp/admin.crt -key /tmp/admin.key`.
   5. Remove the copied files: `rm -f /tmp/admin.crt /tmp/admin.key`.

   The backup keeps the existing users, including the GroundX application user, so search keeps working. See the OpenSearch [securityadmin documentation](https://docs.opensearch.org/latest/security/configuration/security-admin/).

7. Upgrade GroundX with the values from steps 2 to 5 and the images from step 2, then restart `groundx`, wait for it (`kubectl rollout status -n eyelevel deployment/groundx`), and restart `process`. Images without certificate verification keep working across the certificate swap.

   If the GroundX upgrade fails, fix forward: confirm the Secret GroundX uses for OpenSearch holds the CA that signed `node.crt` (`openssl verify -CAfile ca.crt node.crt` against its `ca.crt`): `search.caSecretName` when it is set, otherwise the `fileAccess.caSecretName` bundle. Correct that Secret and run the GroundX upgrade again. `helm rollback groundx` restores the previous values and images, which only restores service when those images do not verify certificates (chart 0.2.7 and earlier); 0.2.8 and later images reject the operator certificate without its CA too. A GroundX rollback does not undo the OpenSearch steps: OpenSearch keeps your certificates, its users and its admin password, so after an admin password rotation the previous `search.privilegedPassword` no longer works. Do not roll OpenSearch back to the demo configuration.

If `search.privilegedPassword` does not match the real admin password, the GroundX API crash-loops with an unauthorized error when it has to create or update its OpenSearch user: on a first install, or after `search.password` changes. On an existing install the mismatch is otherwise silent, so run the check above. If you deploy a Terraform `search` object with `cluster.search = true`, `password` and `root_password` must be non-empty and not an angle-bracket placeholder; an ingest-only install (`cluster.search = false`) needs neither. The operator module now requires Terraform 1.9 or later.

### Trusting OpenSearch with its own CA

To trust OpenSearch with its own CA instead, create a Secret whose `ca.crt` is the CA that signed `node.crt` and set `search.caSecretName` to its name. When set, it takes precedence over the bundle for OpenSearch only; every other connection still uses `fileAccess.caSecretName`. It needs `groundx` and `process` images built with cashbot-go #1877 or later; older images ignore it and keep using the bundle.

`groundx` and `process` images with certificate verification (cashbot-go #1865) check the OpenSearch certificate against this bundle, or against `search.caSecretName` when it is set and the images include cashbot-go #1877; older images skip the check.

### Rotating certificates

To renew the node certificate from the same CA, update `opensearch-tls` and restart `opensearch-cluster-master`. To move to a new CA, add the new CA to the Secret GroundX uses for OpenSearch and keep the old one: the `search.caSecretName` Secret when it is set (its `ca.crt` may hold both CAs), otherwise the `fileAccess.caSecretName` bundle, which `search.caSecretName` replaces for OpenSearch. Restart `groundx` and then `process`, then update `opensearch-tls` with the new CA and a node certificate it signed and restart `opensearch-cluster-master`. Issue a new operator admin certificate with the same subject (`CN=gx-opensearch-admin`) from the new CA, because OpenSearch checks the admin certificate against that CA and the old one stops working for `securityadmin.sh`. Remove the old CA from that Secret, then restart `groundx` and then `process`; from the bundle, only once nothing else trusted through it, such as Redis or object storage, still uses it. A running pod rereads the files only on restart, so trust in the new CA must reach `groundx` and `process` before OpenSearch serves a certificate from it.

### Certificate errors

While GroundX uses this in-cluster OpenSearch (no `search.existing.url`, and `mode` is not `ingest`), the chart will not render with both `search.caSecretName` and `fileAccess.caSecretName` empty. If the Secret GroundX uses for OpenSearch does not hold the CA that signed `node.crt`, `groundx` exits at startup and `process` fails its OpenSearch calls with `request timed out`: the client reports the rejected certificate as a timeout, so the log does not mention `x509`.

## Persistent storage

`groundx-storageclass` 0.1.2 is published in the [GroundX Helm repository](https://registry.groundx.ai/helm/index.yaml). Pin `--version 0.1.2` when relying on its encrypted-by-default EBS settings and live-cluster upgrade guard. Check the installed version before upgrading; older releases do not provide those behaviors.

GroundX uses one app-wide persistent storage abstraction. Set `cluster.pvClass` to the Kubernetes storage class name and `cluster.pvAccessMode` to the access mode that class supports. Services that need PVCs, including summary inference, ranker inference, layout inference, and workspace when enabled, inherit those values unless their local `pvc` block explicitly overrides them.

Prefer a shared filesystem class with `ReadWriteMany` when available:

```yaml
cluster:
  pvClass: eyelevel-pv
  pvAccessMode: ReadWriteMany
```

Use this mode when multiple pods need to share a mounted cache or model/data volume. Workspace does not require this for the primary local-git workflow, but it is useful when the secondary file API cache is configured as a PVC. Example storage class values are included for common shared filesystems:

- EKS/EFS: `src/groundx/prereqs/storageclass/values.efs.example.yaml`
- AKS/Azure Files: `src/groundx/prereqs/storageclass/values.azure-files.example.yaml`
- GKE Filestore: `src/groundx/prereqs/storageclass/values.gke-filestore.example.yaml`

When only block or local storage is available, use `ReadWriteOnce`:

```yaml
cluster:
  pvClass: eyelevel-pv
  pvAccessMode: ReadWriteOnce
```

An EKS/EBS example is available at `src/groundx/prereqs/storageclass/values.ebs.example.yaml`. With `ReadWriteOnce`, any pod family sharing the same PVC must be scheduled in a compatible shape because the volume cannot be mounted freely across nodes.

For AWS EKS, `terraform/aws/setup-eks` generates `src/groundx/prereqs/storageclass/values.aws.local.yaml` and `src/groundx/values.aws.local.yaml` from Terraform outputs. Use `STORAGE_DRIVER=efs` for the shared EFS path or `STORAGE_DRIVER=ebs` for EBS. The generated Helm commands printed by the script do not require manually editing the EFS filesystem ID.

**Upgrade note (EBS encryption default):** starting with `groundx-storageclass` `0.1.2`, a new EBS install (provisioner `ebs.csi.aws.com`, or the legacy in-tree `kubernetes.io/aws-ebs`) renders `parameters.encrypted: "true"` by default -- an operator opting out sets `encrypted: "false"` explicitly (unquoted `false`, `null`, and `""` are equivalent opt-out spellings). An already-installed StorageClass is never changed by a real `helm upgrade --install`: the chart reads the live class via Helm's `lookup` function and, when the class already exists, renders its current live `parameters` verbatim instead of the chart's new defaults -- `helm upgrade` never attempts to change a StorageClass's `parameters`, which Kubernetes treats as immutable once the object is created.

When the class exists and any supplied parameter (`encrypted`, `kmsKeyId`, `type`, or a provisioner-specific one) differs from the live class, the chart's install notes print one line naming each parameter that was not applied. This `lookup` guard only sees a live cluster: `helm template`, a client-side dry run, and GitOps renderers have no live cluster to query, so those flows always render the new-install defaults -- an operator managing an existing class that `0.1.1` created without an explicit `encrypted` value must set `encrypted: "false"` explicitly to keep it unchanged.

This does not work for a class that `0.1.1` created with an explicit `encrypted: "false"`: `0.1.2` never renders an explicit `false`, so a no-live-cluster render omits the key, the rendered class then differs from the live one, and the apply fails on an immutable parameter. For that class, use a live-cluster `helm upgrade --install` (the `lookup` keeps the live value), stay on `0.1.1` in that flow, or create a new StorageClass.

Changing an existing class's actual encryption requires creating a new StorageClass, because `parameters` cannot be updated in place. Pin `--version 0.1.2` when using these StorageClass behaviors, and run `helm repo update` before installing from the published repository.


## Summary GPU sizing

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in more detail in the [Total Recommended Resources](../README.md#total-recommended-resources) section above.

The default configuration for this service is sized for an NVIDIA GPU with 48 GB of GPU memory, 4 CPU cores, and at least 30 GB RAM. It deploys 2 pods on this node (called `summary.inference.replicas.desired` in `values.yaml`). It does not claim the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator), so every summary pod scheduled to a node shares that node's GPU.

Each summary pod runs `summary.inference.workers` workers, and each worker loads its own copy of the model and reserves `summary.inference.deviceUtilize` of the GPU's total memory (a fraction from 0 to 1). On each summary GPU node, pods x `summary.inference.workers` x `summary.inference.deviceUtilize` must be at most 1. With the defaults this is 2 x 1 x 0.48 = 0.96. Each worker's share must also hold the model and its cache: on a 24 GB GPU a share of 0.48 is too small, so the default values do not fit a 24 GB GPU.

For one 24 GB summary GPU, run a single summary pod with one worker:

```yaml
summary:
  inference:
    replicas:
      min: 1
      desired: 1
      max: 1
    workers: 1
    deviceUtilize: 0.9
    updateStrategy: Recreate
```

Apply these values to a running install with `helm upgrade`, passing the file with `-f` after your other values files. With `updateStrategy: Recreate`, Kubernetes stops the old summary pods before it starts the new one, so summary is unavailable on each upgrade until the new pod has loaded its model (the load took about 5 minutes in the test run). Without it, the default rolling update starts the new pod while the old pods still hold the GPU, and the new pod cannot load its model.

These values assume the summary pod has the node's GPU to itself. They were tested on an AWS `g5.2xlarge` (one NVIDIA A10G, which reported 23028 MiB of GPU memory) with the `summary-inference:0.2.7` image and helm `v3.19.0+g3d8990f`, applied as an in-place `helm upgrade` to an install running the default values. Other 24 GB GPUs, such as the NVIDIA L4, were not tested.

With several summary GPU nodes, or with `cluster.hpa: true` and `summary.inference.replicas.max` above 1, more than one summary pod can land on the same node and share its GPU. To keep one pod per GPU, set `nvidia.com/gpu: 1` under both `requests` and `limits` in `summary.inference.resources`, or spread the pods across nodes with `summary.inference.topologySpreadConstraints`.

Each pod then has a GPU to itself, so on 24 GB GPUs use the `summary.inference.workers` and `summary.inference.deviceUtilize` values from the block above. In either case, keep `summary.inference.replicas.max` at or below the number of summary pods your summary GPU nodes can hold.

With a GPU request, keep `updateStrategy: Recreate` unless a spare GPU is free, because a rolling update's new pod waits Pending for the GPU the old pod holds. Every summary pod mounts the same model volume claim, so pods on more than one node need ReadWriteMany storage for that claim.

The claim inherits `cluster.pvAccessMode` and `cluster.pvClass`; if that is not already ReadWriteMany on a storage class that supports it, set `summary.inference.pvc.access: ReadWriteMany` and such a class in `summary.inference.pvc.class` (see [Persistent storage](#persistent-storage)). Kubernetes does not let a claim that already exists change its access mode, so on an existing install also set a new `summary.inference.pvc.name` (the default is `summary-model`): the upgrade creates a new claim, the summary pods download the model into it again, and Helm removes the old claim because the chart no longer renders it.

With ReadWriteOnce storage the volume can be mounted by one node only, so a pod scheduled to a second node cannot start; keep summary on one node instead.

For the 48 GB defaults, `updateStrategy: Recreate` is also recommended, with the same brief outage on each upgrade. Without it, Kubernetes' default rolling update starts a third summary pod on the node before it stops an old one, three pods at 0.48 need 1.44 of the GPU, and the new pod cannot load its model. This advice follows from that arithmetic and from the 24 GB test without `Recreate`, where the rollout stalled the same way; it was not tested on a 48 GB GPU.

If your machine has different resources than this, you will need to modify `summary.inference` in your `values.yaml` using the per pod requirements described above to optimize for your node resources.

Note: in many cloud Kubernetes services, such as EKS, you must use a node image that supports GPUs (e.g. AL2023_x86_64_NVIDIA).
