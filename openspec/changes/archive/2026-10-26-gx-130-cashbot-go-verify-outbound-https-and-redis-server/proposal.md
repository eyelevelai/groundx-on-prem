## Why

The GX-130 cashbot-go change makes cashbot-go verify TLS certificates on its outbound HTTPS and Redis clients. An on-prem install that reaches a private or self-signed endpoint must be able to give GroundX workloads its own CA bundle before that release rolls out, and the ticket owner made this chart support a precondition for merging and releasing the cashbot-go change.

On the 0.2.8 line (895ca7a35) the chart already has this mechanism: `fileAccess.caSecretName` mounts a CA bundle and sets `SSL_CERT_FILE`. It only renders when `fileAccess.enabled` is true, and the metrics Deployment never includes it, although the metrics server also opens Redis.

Authority: the GX-130 Linear issue body ("explicit private CA support where required"; "install and verify private trust before rolling consumers"), comment 22b9abc9 (2026-10-23, CA mounting is needed in on-prem now, with a migration path) and comment 3eead613 (2026-10-26, the scope below).

## What Changes

- The `groundx.fileAccess.caEnv`, `caMount` and `caVolume` helpers render whenever `fileAccess.caSecretName` is set. They no longer also require `fileAccess.enabled`.
- The metrics Deployment includes the three helpers, like the other workloads under `templates/app/`.
- `helm/` mirrors the `src/groundx/` template edits byte for byte.
- One new helm-unittest case covers file access off, `caSecretName` set and metrics on: the metrics Deployment and a Go Deployment both carry `SSL_CERT_FILE`, the `file-access-ca` mount and the Secret volume.
- `docs/agents/private-file-access.md` states that the CA reaches every GroundX application workload, metrics included, whether or not file access is enabled, and that the Secret must exist before the upgrade. The opening sentence that says workloads stay unchanged while file access is disabled is qualified accordingly.
- No new values key, environment variable or mechanism. With `caSecretName` empty (the default) the chart is expected to render the same manifests as before. Not breaking.

## Capabilities

### New Capabilities

- `operator-ca-trust`: the chart delivers an operator CA bundle to every GroundX application workload whenever `fileAccess.caSecretName` is set, independent of file access.

### Modified Capabilities

None. The CA helpers were added by the active `protect-hosted-file-access` change, whose `local-file-gateway` spec does not mention `caSecretName`.

## Blast radius and rollout

- **Who redeploys.** Any cluster that installs or upgrades to a chart from the 0.2.8 line. The released 0.2.7 chart has no `caSecretName` key, so an upgrade from 0.2.7 changes these manifests only when the operator sets it.
- **Key empty.** No rendered change is expected. The repo gate (`.build/bin/validate-helm.sh`) checks the existing snapshots; they are not regenerated for this change.
- **Key set.** Every application workload (the Go Deployments, API, Celery, inference, the schema-migration Job and metrics) gets the mount and `SSL_CERT_FILE`, so their pods are replaced on upgrade.
- **What can break.** The Secret volume is not optional: if the Secret or its `ca.crt` key is missing, every pod that mounts it fails to start. A bundle holding only the private CA can break calls to public HTTPS endpoints, so operators must supply a complete trust bundle, as the doc already requires. A rotated bundle needs a pod restart.
- **Environments and data.** Applies to any cluster deployed from this chart. No database, volume claim or stored data changes.
- **Order.** Create the CA Secret, upgrade the chart with `caSecretName` set, confirm the pods are Ready, then roll the cashbot-go release that enforces verification.
- **Rollback.** Clear `caSecretName` and upgrade again, or `helm rollback` to the previous revision. Do not roll back by disabling certificate verification in cashbot-go.

Open design questions: none.

## Impact

- Templates: `src/groundx/templates/_helpers/app/file-access.tpl`, `src/groundx/templates/app/metrics.yaml`, and their `helm/templates/` mirrors.
- Tests: `src/groundx/tests/file_settings_test.yaml`.
- Docs: `docs/agents/private-file-access.md`.
- Consumers: cashbot-go needs no change; Go reads `SSL_CERT_FILE` for its system trust. ai-server pods receive the same variable, but whether each Python client honors it is out of scope (GX-131). groundx-studio-harness documents the key in its own change.
- Out of scope: the bundled OpenSearch demo certificates (GX-90) and ai-server Celery Redis verification (GX-131).
