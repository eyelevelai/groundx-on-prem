# Deployment and upgrade notes

Use these notes for storage and GPU configuration, or when upgrading an existing installation. Commands run from the repository root unless stated otherwise. Keep your customized values file and back up stateful services before upgrades.

Before a GroundX application upgrade, follow the [database migration requirements](agents/database-upgrades.md). Do not replace an existing values file with the new-install sample. To enable the file gateway on existing data, complete the [existing-file activation procedure](agents/private-file-access.md#upgrade-existing-files-before-activation).

- [Redis TLS upgrades](#redis-tls-upgrades)
- [OpenSearch installation and credentials](#opensearch)
- [Persistent storage](#persistent-storage)
- [Summary GPU sizing](#summary-gpu-sizing)
- [Inference model downloads](#inference-model-downloads)
- [MinIO migration and recovery](storage/minio-migration.md)

## Redis TLS upgrades

Chart 0.2.8 images verify the certificate chain and the host name of a `rediss://` Redis in the layout, ranker and summary services, both the APIs and the workers. This applies when you set `ssl: true` under `cache.existing`, under the ranker-only `ranker.cache`, or under `cache.metrics.existing` for a separate metrics Redis; the certificate must cover the `addr` host name of each. A plain `redis://` Redis, including the Redis the chart installs, is unaffected. A certificate that chains to a public root needs no action.

If your Redis certificate comes from a private CA, or does not cover the `addr` host name, act before upgrading. Build a complete CA bundle from the public root CAs plus your private CA, store it in a Secret under the key `ca.crt` in the GroundX namespace (the `namespace` value, `eyelevel` by default), and set `fileAccess.caSecretName` to its name. If `fileAccess.caSecretName` is already set, for example for a private object-store CA, add the Redis CA to that Secret's `ca.crt` instead. Alternatively, correct `addr` to a host name the certificate covers.

The bundle replaces the container's default CA file. A Secret that holds only the private CA breaks the HTTPS calls that rely on public roots, such as an LLM API or an object store, so keep the public roots and any CAs already in the bundle.

If you skip this and a certificate does not verify, ingest, search and summary requests fail and the workers stop publishing and consuming tasks. The ai-server API and worker pods stay Ready even when they cannot connect, so after upgrading check the layout, ranker and summary logs for `certificate verify failed`.

A Workspace runner image that includes the AGE-403 fix verifies a `rediss://` Redis the same way, for both its Celery broker and result backend, and trusts a private CA through the same `SSL_CERT_FILE`. When your release selects such an image and a certificate does not verify, the `workspace-*` workers cannot reach Redis, so also check their logs for `certificate verify failed`. A `workspace.celeryBrokerUrl` or `workspace.celeryResultBackend` override that sets an `ssl_*` option in its URL query stops those pods at startup; remove the option.

The original chart 0.2.8 rollout verified the ai-server layout, ranker and summary clients. Its notes recorded that the extract client (AGE-395) and Workspace runner still accepted any certificate. Do not infer platform-wide verification from these results; check the extraction and Workspace images selected for your release.


## OpenSearch

### Installing OpenSearch

If you'd like to install OpenSearch to your cluster, first choose the OpenSearch admin password. It must be the same value you later provide to GroundX as `search.privilegedPassword` in your `values.yaml` or as `SEARCH_INIT_PASSWORD` in the cluster credentials Secret (the Secret route needs `groundx` and `process` images that read it; see GroundX password delivery below). Supply it to OpenSearch through a Kubernetes Secret, so the password is not written into the OpenSearch StatefulSet pod spec where anyone who can read pods in the namespace could see it. Restrict permissions before each file exists, and create it in an editor rather than with a shell command so the password is not saved to your shell history:

```bash
umask 077
```

Create `opensearch-admin-secret.yaml` in an editor with this content, then confirm it is owner-only with `chmod 600 opensearch-admin-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: opensearch-admin
  namespace: eyelevel
type: Opaque
stringData:
  OPENSEARCH_INITIAL_ADMIN_PASSWORD: "<opensearch-admin-password>"
```

Apply the Secret, then delete the local file:

```bash
kubectl apply -f opensearch-admin-secret.yaml
rm opensearch-admin-secret.yaml
```

Create `opensearch-admin.values.yaml` with this content. It references the Secret instead of embedding the password, so this file holds no credential:

```yaml
extraEnvs:
  - name: OPENSEARCH_INITIAL_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: opensearch-admin
        key: OPENSEARCH_INITIAL_ADMIN_PASSWORD
```

Then install OpenSearch with both values files:

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm install opensearch opensearch/opensearch -n eyelevel -f helm/values/opensearch/values.yaml -f opensearch-admin.values.yaml
```

Choose a password you have not published anywhere. The GroundX chart rejects a known published default for `search.password` or `search.privilegedPassword` and fails to render if you supply one, so an upgrade that silently keeps the old default (for example `helm upgrade --reuse-values`) will not deploy.

OpenSearch requires `OPENSEARCH_INITIAL_ADMIN_PASSWORD` at every start, not only on first initialization. On an already-initialized data volume it is still read at boot, and a start without it exits with `No custom admin password found` (observed on image digest `sha256:8e95a30f…`). Keep `-f opensearch-admin.values.yaml` on every `helm upgrade opensearch …`, not just the first install, and pin the OpenSearch image to a digest so this stays reproducible. The value is consumed only to initialize an empty volume; changing it on an existing volume does not rotate the stored admin password (rotate with the backup route under Upgrading existing OpenSearch). The Secret must exist before OpenSearch starts, which the order above ensures.

Rotating these passwords does not by itself secure OpenSearch for production: the documented install still trusts OpenSearch's demo TLS certificates, and the GroundX application user has broad privileges. For production, also replace the demo certificates with operator-supplied ones and restrict network access to OpenSearch.


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

Earlier chart versions defaulted both OpenSearch passwords to a public value. An OpenSearch data volume created with them keeps its original admin password, because the seed value is only read on first initialization. Before upgrading:

1. Set `search.privilegedPassword` (or `SEARCH_INIT_PASSWORD`, which needs the `groundx` and `process` images described under GroundX password delivery) to the admin password your OpenSearch currently uses, unless that is a published default. The chart rejects a published default supplied through values and will not render, so if your install still uses one, first rotate the OpenSearch admin password off it with the admin-password route in step 3, then set `search.privilegedPassword` to the new value. When you upgrade the OpenSearch release itself, keep `-f opensearch-admin.values.yaml` on the `helm upgrade opensearch` command: the image requires `OPENSEARCH_INITIAL_ADMIN_PASSWORD` at every start, and a restart without it fails with `No custom admin password found`.
2. Set `search.password` (or `SEARCH_PASSWORD`) to the application user password your install currently uses, unless that is a published default. The chart rejects a published default supplied through values, so if your install still uses one, choose a new application password for the upgrade. Make sure `search.privilegedPassword` already holds the correct admin password (from step 1 or the step 3 rotation) before changing `search.password`, or the GroundX API crash-loops when it re-creates `search.username`; confirm with the login check in step 3.
3. Rotate the credentials. The OpenSearch `admin` user is reserved, so the security REST API refuses to change it (it returns 403 "Resource 'admin' is reserved"). Use these routes instead:
   - Application password: set a new `search.password` and upgrade, or change `SEARCH_PASSWORD` in the Secret and restart `groundx` and then `process` as described under GroundX password delivery. The GroundX API re-creates `search.username` with it, using the admin credential, when its login is rejected.
   - Admin password: open a shell in the OpenSearch pod (for example `kubectl exec -it -n eyelevel opensearch-cluster-master-0 -- bash`) and run these steps. Start from a backup of the stored users, not the image's `internal_users.yml`, because uploading that file replaces the whole stored user list and would drop every user created through the REST API, including the GroundX application user, and break search.
     1. Back up the stored security configuration: `plugins/opensearch-security/tools/securityadmin.sh -backup /tmp/security-backup -icl -nhnv -cacert config/root-ca.pem -cert config/kirk.pem -key config/kirk-key.pem`.
     2. Run `plugins/opensearch-security/tools/hash.sh` without `-p` so it prompts for the password and keeps it out of shell history.
     3. Put the printed hash as the `admin` hash in `/tmp/security-backup/internal_users.yml`.
     4. Upload only the users: `plugins/opensearch-security/tools/securityadmin.sh -f /tmp/security-backup/internal_users.yml -t internalusers -icl -nhnv -cacert config/root-ca.pem -cert config/kirk.pem -key config/kirk-key.pem`.

     The backup keeps the existing users, including the GroundX application user, so search keeps working. See the OpenSearch [securityadmin documentation](https://docs.opensearch.org/latest/security/configuration/security-admin/).
   - Then set `search.privilegedPassword` to the new admin password and upgrade. Confirm the rotation from inside the pod with `curl -k -u admin https://localhost:9200/_plugins/_security/authinfo`, which prompts for the password: the new password must succeed and the old one must be rejected.

If `search.privilegedPassword` does not match the real admin password, the GroundX API crash-loops with an unauthorized error when it has to create or update its OpenSearch user: on a first install, or after `search.password` changes. On an existing install the mismatch is otherwise silent, so run the check above. If you deploy a Terraform `search` object with `cluster.search = true`, `password` and `root_password` must be non-empty and not an angle-bracket placeholder; an ingest-only install (`cluster.search = false`) needs neither. The operator module now requires Terraform 1.9 or later.

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

- EKS/EFS: `src/groundx/prereqs/storageclass/values.efs.example.yaml` (new installs using this example set `cluster.pvClass: eyelevel-efs`; existing EFS releases keep their current `storageClassName`)
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

## Inference model downloads

The layout, ranker and summary inference pods download their model the first time they start. One pod downloads while the others wait. If the downloading pod is killed, the next pod takes over. If the download fails, the pod shows `Init:Error` and retries, instead of starting with a partial model.

**Before you upgrade or roll back** while a model is still downloading for the first time:

1. Scale the inference deployments to 0.
2. Wait until all their pods are gone. An old pod can keep downloading until its shutdown grace period ends.

   ```bash
   kubectl wait -n eyelevel --for=delete pod -l 'app in (layout-inference,ranker-inference,summary-inference)' --timeout=20m
   ```

3. Upgrade or roll back, then scale the deployments back up.

Old and new pods use different locks, so they must not download into the same volume at the same time. If every model has already downloaded, you can skip these steps.

**If an inference pod cannot load its model after upgrading:** older charts could mark a failed download as complete. Scale that service to 0, wait until its pods are gone (`kubectl wait -n eyelevel --for=delete pod -l app=summary-inference --timeout=20m` for summary), delete the `complete.<model>` file from its model volume, and scale it back up. The next pod downloads the model again.

**Air-gapped clusters:** the pods cannot download the model. Copy the model files and the `complete.<model>` file into the model volume before scaling up.

**Custom busybox image (`busybox.image`):** it must include `flock`. Without it, a pod that needs to download its model fails at once with a message naming `flock`.
