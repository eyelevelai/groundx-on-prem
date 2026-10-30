## Goals / Non-Goals

**Goals**

- Give an operator with a `rediss://` existing Redis one place in the README that says what chart 0.2.8 ai-server images now verify, what to do first, and what does not yet verify (scope and blast radius: `proposal.md`).

**Non-Goals**

- No template, value, schema, snapshot or `helm/` mirror change, no verification toggle, no new CA mechanism, no change to `busybox`. The CA mount is the existing `fileAccess.caSecretName` path; this change documents it.

## Decisions

### D1. One `####` note in the existing-Redis section, README only

The note goes after the existing-Redis paragraph and before "Deploying a Dedicated Redis Cluster", titled "Upgrading to Chart 0.2.8 with a `rediss://` Redis", in the same style as the per-version notes lower in the README (for example "Object Keys That Start with a Slash"). A new `docs/` page was rejected: the operator who needs it is reading the existing-Redis instructions, and a link adds a hop for three short paragraphs. The README is in the validate gate's scope (`.build/bin/verify-storage-contract.py` stale-string scan, `git diff --check`), so the gate covers the edit.

### D2. Note content (decided wording points)

1. Chart 0.2.8 images verify chain and host name for `rediss://` in the layout, ranker and summary services (APIs and workers); this applies when `ssl: true` is set under `cache.existing` (`src/groundx/values.yaml:42-46`, `src/groundx/templates/_helpers/services/cache.tpl:252-260`) or under the ranker-only `ranker.cache` (`src/groundx/values.yaml:411-418`, `src/groundx/templates/_helpers/app/ranker.tpl:32-39`), and the certificate must cover the `addr` of each; plain `redis://` and the bundled Redis are unaffected; a publicly rooted certificate needs no action.
2. A private-CA certificate, or a host name the certificate does not cover, makes ingest, search and summary requests fail and the workers stop publishing and consuming after the upgrade. Before upgrading: create a Secret, in the GroundX namespace (the `namespace` value, `eyelevel` by default), with the CA certificate under key `ca.crt` and set `fileAccess.caSecretName` (or, when it is already set, add the Redis CA to that Secret's `ca.crt`), or correct `addr`. The note states the mount condition plainly (the CA is mounted from `fileAccess.caSecretName`; a chart that still requires `fileAccess.enabled` for that mount needs a release that removes the requirement) and does not describe behavior the chart at this head lacks.
3. The CA file replaces the container's default CA file, so the bundle keeps the public roots and any CAs already in it that the same pods still need.
4. Not every client verifies: the extract client (AGE-395) and the workspace runner do not yet.

No present-tense claim about a deployed environment is written; the note describes chart 0.2.8 image behavior.

### D3. Merge gate on the GX-130 on-prem change

At base `origin/0.2.8` (`895ca7a35`) the CA env var, volume and mount helpers render only when `fileAccess.enabled` is true (`src/groundx/templates/_helpers/app/file-access.tpl:1-3,191-215`; default `fileAccess.caSecretName: ""` at `src/groundx/values.yaml:99`). The note tells operators to set `fileAccess.caSecretName` without enabling file access, which is accurate only once the sibling GX-130 on-prem change stops gating the CA mount on `fileAccess.enabled`. This PR therefore merges with or after that change. This is a merge-order condition, not a claim about the sibling's content; the merge-order dependency is carried in the PR body, and the README states only the mount condition.

### D4. Rollout and blast radius

README-only: no cluster redeploys, no stateful resource is touched, and rollback is reverting the commit. The behavior the note documents ships in the ai-server `:0.2.8` images with the 0.2.8 chart (never as a rebuilt `:0.2.7`). Producer contract shapes: this change adds none; see `contract.md` for the cross-service CA-delivery and broker-URL touchpoints. Classification: the touchpoint is `Additive` for `redis://` and for `rediss://` that verifies, and `Breaking` for `rediss://` that does not; the compatibility mechanism is the documented `fileAccess.caSecretName` route (already present at `values.yaml:99`), with no feature flag by decision.

### D5. Verification

Each decision point is a runnable `grep`/`sed` check on the note's section of `README.md` (see `tasks.md`); the whole change is gated by the repo's pre-push `validate-helm.sh`, which the pipeline does not execute as an acceptance check because the repo is privileged. The checks avoid repo scripts.

## Amendments

- 2026-10-28: after review on the merged change, the README note was revised on `main`. The first CA instruction now says to build a complete bundle (public roots plus the private CA); the `fileAccess.enabled` sentence was dropped because the published 0.2.8 chart mounts the CA whenever `fileAccess.caSecretName` is set; a separate metrics Redis (`cache.metrics.existing` with `ssl: true`) was added; and the note tells operators to check the layout, ranker and summary logs after upgrading, because the API `/health` handlers (`document_api_server.py`, `ranker_server.py`, `summary_server.py` at ai-server `1b28e523`) never touch Redis and the Celery workers' readiness only checks the process, so those pods stay Ready while every worker logs `certificate verify failed`; a local minikube upgrade on 2026-10-28, with the inference workers and the GroundX Go services disabled, showed the same. In a full install the GroundX Go services verify the same Redis and fail to start, so the logs and pod status together show the failure. The inference pods' readiness calls `/health`, which reads worker state from the metrics Redis (`document_health.py` through `status.get_worker_state`), so they go unready when that Redis fails verification. The living spec `existing-redis-tls-upgrade-guidance` carries the revised requirements; this change's task checks describe the note as first shipped.
