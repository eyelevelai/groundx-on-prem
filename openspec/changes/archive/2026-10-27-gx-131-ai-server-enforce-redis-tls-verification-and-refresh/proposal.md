## Why

The ai-server change for GX-131 makes the layout, ranker and summary Celery clients, and the summary API result backend, verify the certificate chain and host name of a `rediss://` Redis. Until now they connected without verifying. An operator who points `cache.existing` (or a per-service cache) at a TLS Redis whose certificate does not chain to the container's default trust will see those workers stop publishing and consuming after upgrading to chart 0.2.8 images. The chart README's existing-Redis section says nothing about this, so the operator has no warning and no documented fix.

## What Changes

- Add one upgrade note to the README "Using an Existing Redis Cluster" section (`README.md:406`), beside the other per-version notes (for example `README.md:605`). It states:
  - Chart 0.2.8 images verify chain and host name for a `rediss://` Redis in the ai-server layout, ranker and summary services (APIs and workers), when `ssl: true` is set under `cache.existing` or the ranker-only `ranker.cache` (the certificate must cover the `addr` of each). Plain `redis://`, including the bundled Redis the chart installs, is unaffected.
  - A certificate that chains to a public root needs no action. A certificate from a private CA needs a Secret, in the release namespace, holding the CA certificate under key `ca.crt`, referenced by `fileAccess.caSecretName` (or the Redis CA added to the existing Secret's `ca.crt` when `fileAccess.caSecretName` is already set), or a corrected `addr`, before upgrading.
  - The CA file replaces the container's default CA file, so the bundle keeps the public roots and any CAs already in it that the same pods still need (for example for object-store HTTPS).
  - Which clients verify and which do not yet: ai-server layout, ranker and summary verify; the extract client (AGE-395) and the workspace runner do not.
- No template, values, schema or `helm/` mirror change. No new value or toggle; verification cannot be turned off.
- No change to `busybox:1.0.0` or its chart default. The image has no trust store; its model-download init container is recorded in the ai-server evidence and handed to GX-134.

## Capabilities

### New Capabilities

- `existing-redis-tls-upgrade-guidance`: the README states the verified-TLS behavior change for `rediss://` Redis in chart 0.2.8, what operators with a private CA must do before upgrading, and which clients verify.

### Modified Capabilities

None. No existing spec's requirement changes; `redis-authenticated-credentials` covers credentials, not TLS trust.

## Impact

- **Files:** `README.md` only. `helm/README.md` is a separate short file and is not touched; `README.md` is in the validate gate's scope (`.build/bin/verify-storage-contract.py:334` stale-string scan, `git diff --check`).
- **Blast radius of this change:** none at runtime. No cluster redeploys because of this PR.
- **Blast radius it documents (ai-server images, not this repo):** for a `rediss://` customer whose certificate is not trusted, layout, ranker and summary workers and the summary API fail to enqueue, consume and read chord results until the CA Secret or host name is fixed. Environments: customer self-hosted installs on chart 0.2.8; hosted environments are owned by the release owner's pre-rollout check in the ai-server PR. Stateful resources: this README-only change does not touch queue state or stored data.
- **Rollback:** revert the README commit. Operators who hit the failure before the CA is in place stay on, or return to, the previous chart release until the Secret is created; this README-only change does not alter queue contents.
- **Dependency on GX-130 (merge gate):** at base `origin/0.2.8` (`895ca7a35`) the CA env var, volume and mount helpers are gated on `fileAccess.enabled` (`src/groundx/templates/_helpers/app/file-access.tpl:1-3,191-215`), which defaults to false. The note is accurate for customers who do not enable file access only once GX-130's on-prem change removes that gate and mounts `fileAccess.caSecretName` into the api, celery and inference workloads. This PR merges with or after the GX-130 on-prem PR, and the note must not describe the CA mount as available on chart 0.2.7.
- **Cross-service:** the ai-server `:0.2.8` images ship only with the 0.2.8 chart that carries GX-130 (never as a rebuilt `:0.2.7`). The harness skill guidance is a separate PR in `groundx-studio-harness`.
- **Open design questions:** none. The earlier open question about `busybox:1.0.0` is resolved: record and hand to GX-134, no change here.
