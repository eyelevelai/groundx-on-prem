## Goals / Non-Goals

**Goals:**
- With file access on, the `post-process` worker receives the feature storage Secret like every other Go storage consumer (proposal.md, Why).
- Both chart surfaces render the change and stay byte-identical.

**Non-Goals:**
- Other workers' Secret handling, S3 IAM role, config-yaml `upload.id`/`upload.secret`, cashbot-go (proposal.md, Out of scope).

## Decisions

**Invariant:** a Go service receives the feature storage Secret exactly when it is a storage client and file access is created, so the `$consumers` list in `groundx.fileAccess.workloadSecrets` must contain every Go service that reads storage, not only a subset of them.

1. Add `"postProcess"` to `$consumers` in `src/groundx/templates/_helpers/app/file-access.tpl` and the byte-identical `helm/templates/_helpers/app/file-access.tpl`. `app/golang.yaml` already passes the service name to `groundx.fileAccess.workloadSecrets` and `postProcess` is already in the Go service list in `app/golang.tpl`, so no other template changes. The mechanism is the existing list; no new helper, value or schema field.
2. Tests extend `src/groundx/tests/file_settings_test.yaml` with an on-case (file access plus post-process values, `post-process` `envFrom` contains `file-store-credentials`) and an off-case (file access off, `envFrom` absent). The off-case alone passes on unchanged code, so the on-case is the RED signal and both are authored and run together.
3. `.build/bin/validate-helm.sh` asserts the post-process Secret in the existing two-chart FileAccess loop so `src/groundx` and `helm` are both rendered; no new loop or file.
4. No snapshot changes: no snapshot covers a post-process render with file access on.

Producer contract shapes: none; INDEPENDENT change with no cross-service contract.

## Risks / Rollout

- Blast radius: only the `post-process` Deployment gains an `envFrom` entry and rolls its pods once on upgrade. Installs without `postProcess.enabled` (default off) or without file access render identically.
- The referenced Secret already exists for the other consumers; no ordering or prerequisite is added.
- Rollback: revert the list entry; the pod rolls once more.
- Verified by `helm unittest` and the `validate-helm.sh` gate, which also byte-compares `src/groundx/templates` against `helm/templates`.
