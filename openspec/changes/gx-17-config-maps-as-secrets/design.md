# Design — GX-17: Render credential-bearing config maps as Secrets (chart-only)

## Approach

In-place kind conversion: `kind: ConfigMap` → `kind: Secret`, `data:` → `stringData:` (Kubernetes base64-encodes at apply), and the pod volume source `configMap:`/`name:` → `secret:`/`secretName:`. Resource names and mount paths are unchanged, so the rendered file each pod mounts is byte-identical to 0.2.7. Only credential-bearing maps convert; `*-supervisord-conf`, `*-gunicorn-conf-py`, `config-models`, and `ldconfig-symlink` carry no credentials and stay ConfigMaps.

## Why in-place over one consolidated Secret

The in-place conversion adds no Secret objects on top of the existing set (7 ConfigMaps become 7 same-named Secrets; on upgrade 7 Secrets are created and 7 ConfigMaps deleted; total object count and names unchanged). A single consolidated config Secret was considered and rejected: it puts every credential in one object (one read exposes all — weaker isolation than 0.2.7 has today, against GX-18's goal) for a larger, riskier template refactor. The existing chart Secrets (`extract.agent`, `extract.save`, workspace) are env-var (`envFrom: secretRef`) / TLS shaped; these config files are whole rendered files mounted by `subPath`, a different shape that cannot fold into an env-var Secret without changing how the apps read them.

## RED / GREEN acceptance

Every **runnable** `tasks.md` check is a positive assertion that the target renders `kind: Secret` and still carries its payload key (or that a pod volume references it via `secretName`). This is a real RED/GREEN signal, not a snapshot tautology, and a resource that stopped rendering fails the check rather than passing:
- **RED (base `origin/0.2.7`)**: the credential resources render as `ConfigMap`, so every runnable check fails. Verified against a base worktree at `4259bbc`: `config-yaml.yaml` renders `kind: ConfigMap`; the config-py, extract, and OCR checks fail; the golang pod mounts `config-volume` from `configMap:`.
- **GREEN (this branch)**: the resources render as `Secret` and the pod volumes reference `secretName`, so every runnable check passes. Verified under pinned helm v3.19.0.

Two tasks are deliberately **not** runnable RED/GREEN checks and are marked `n/a`: the "non-credential maps stay ConfigMaps" scope guard (task 5.1) passes on the unchanged base, so it is not a valid RED check — it is a must-not-change invariant covered by the golden-snapshot suite; and the docs update (5.2). What the runnable checks prove is the kind flip, payload-key presence, and the secret volume source. **Byte-identical payload parity** is established separately, by the review-time snapshot diff (below), not per check — a self-contained acceptance check has no base render to diff against.

## Verification

Full `.build/bin/validate-helm.sh` green under pinned helm v3.19.0: `helm lint` (both surfaces), `helm unittest` (204 tests / 815 snapshots), the snapshot-label guard, and the OCR-render verification (asserts a Secret for both chart surfaces). Both chart mirrors verified in sync (`diff -rq src/groundx/templates helm/templates`). Reviewed adversarially, including a cross-family (Codex) pass.

## Migration / rollout

No schema or data migration. On a rolling upgrade the same-named object changes kind (Secret created, ConfigMap deleted) and the mounting pods roll once via `config-hash`. `helm rollback` restores the ConfigMap. Lands via an official chart release; no production hot-patch. Credential rotation is a post-ship step under GX-18.
