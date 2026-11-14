## Why

AGE-403 makes the Workspace runner verify the certificate chain and host name of a `rediss://` Redis for both its Celery broker and its result backend. Until now it accepted any certificate. The chart gives the six `workspace-*` pods a `rediss://` Redis when `cache.existing.ssl` is true, and sets `SSL_CERT_FILE` on all six when `fileAccess.caSecretName` is set. The upgrade guide lists only the layout, ranker and summary pods in its post-upgrade `certificate verify failed` check and says nothing about the Workspace runner's new behavior. An operator whose Redis certificate does not verify would not know to look at the `workspace-*` logs.

## What Changes

- Add one paragraph to `docs/upgrades.md` under "Redis TLS upgrades". It states that a Workspace runner image that includes the AGE-403 fix verifies a `rediss://` Redis the same way for broker and result backend, trusts a private CA through the same `SSL_CERT_FILE`, and that the `workspace-*` logs are checked for `certificate verify failed` when the selected image verifies. It also states that a `workspace.celeryBrokerUrl` or `workspace.celeryResultBackend` URL that sets an `ssl_*` option in its query stops the pods at startup.
- The wording is version-neutral: no release number is stated, because the first release that carries a fixed runner image is not known. The reader is told to check the Workspace image selected for their release.
- Amend the `existing-redis-tls-upgrade-guidance` spec so its requirements describe the new paragraph.
- No template, values, schema, snapshot or `helm/` mirror change. No toggle that turns verification off.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `existing-redis-tls-upgrade-guidance`: the post-upgrade log check names the Workspace pods when the selected image verifies, and the note states the Workspace runner behavior without a release number.

## Impact

- **Files:** `docs/upgrades.md`, and this change's OpenSpec files. `README.md` on this branch only links to the guide.
- **Blast radius:** none at runtime; documentation only. It documents the effect of a runner image (`groundx-workspace-runner`, AGE-403) on installs with an external TLS Redis.
- **Rollback:** revert the documentation commit.
- **Related changes:** `groundx-workspace-runner` AGE-403 (the behavior) and `groundx-studio-harness` (`skills/groundx-on-prem/references`, the matching agent guidance).
- **Open design questions:** none.
