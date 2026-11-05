## Why

With file access on MinIO, AIStor or S4, the chart moves storage credentials out of the shared config and into the `fileAccess.storageCredentialsSecretName` Secret, and adds that Secret to a worker's `envFrom` only when the worker is in the `$consumers` list of `groundx.fileAccess.workloadSecrets`. `postProcess` is not in that list, so the post-process worker reads storage anonymously and its runs fail with `Could not read post-processing input.`.

## What Changes

- Add `"postProcess"` to the `$consumers` list in `groundx.fileAccess.workloadSecrets` in `src/groundx/templates/_helpers/app/file-access.tpl` and the byte-identical mirror `helm/templates/_helpers/app/file-access.tpl`.
- Extend `src/groundx/tests/file_settings_test.yaml` with a post-process case (file access on plus post-process enabled, `post-process` Deployment `envFrom` includes the `file-store-credentials` secretRef), paired in one task and check with a file-access-off case asserting `envFrom` is absent, so the baseline check on unchanged code fails on the on-case.
- Add a post-process Secret assertion to the existing two-chart FileAccess loop in `.build/bin/validate-helm.sh` so both `src/groundx` and `helm` are rendered.
- No snapshot changes, no new files, no values-schema change.

Behavior change: with file access on, the `post-process` Deployment receives the storage credentials Secret. With file access off, its rendered output is unchanged. No stored state is created, removed or migrated.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-file-gateway`: requirement "Feature credentials reach only storage consumers" now includes the post-process worker among the verified Go storage consumers that receive the feature storage Secret.

## Impact

- Code: the two `file-access.tpl` copies, `src/groundx/tests/file_settings_test.yaml`, `.build/bin/validate-helm.sh`. The `postProcess` entry already exists in the Go service list (`src/groundx/templates/_helpers/app/golang.tpl:40`), so the Deployment is rendered by `app/golang.yaml`, which already calls `groundx.fileAccess.workloadSecrets`.
- Affected installs: those with `postProcess.enabled: true` (off by default) and file access on MinIO, AIStor or S4. S3 with an IAM role does not use these credentials. Installs without `postProcess` or without file access render identically.
- Blast radius: on rollout, only the `post-process` Deployment gets a new `envFrom` entry and rolls its pods once; no other workload, Secret, or backing store changes. The referenced Secret must already exist, as it does for the other consumers; no additional prerequisite is introduced.
- Rollback: revert the list entry; the pod rolls again and returns to its previous environment.
- Environments: any cluster deployed from this chart with the conditions above; no data or stateful resource impact.
- Out of scope: other workers' Secret handling, S3 IAM role, config-yaml `upload.id`/`upload.secret`, cashbot-go.
- Open design questions: none.
