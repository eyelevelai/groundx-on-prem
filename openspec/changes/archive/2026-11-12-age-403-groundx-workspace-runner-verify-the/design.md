## Goals / Non-Goals

**Goals**

- Tell an operator with a `rediss://` Redis that Workspace runner images carrying the AGE-403 fix verify the certificate, where to look when it does not verify, and that an `ssl_*` option in a Workspace Celery URL is rejected at startup. Scope and blast radius: `proposal.md`.

**Non-Goals**

- No template, value, schema, snapshot or `helm/` mirror change, no verification toggle, no new CA mechanism. The CA path is the existing `fileAccess.caSecretName` mount, which the chart already applies to all six `workspace-*` pods (`src/groundx/templates/app/api.yaml` and `celery.yaml` include the `groundx.fileAccess.caEnv`, `caMount` and `caVolume` helpers; rendered with `cache.existing.ssl=true` and `fileAccess.caSecretName=my-ca`).
- No release number. Chart `0.2.9` pulls the floating tag `workspace-runner:0.2.9`, so a number cannot be stated until a fixed image is published.

## Decisions

### D1. One paragraph in the existing guide section

The paragraph goes after the sentence that tells operators to check the layout, ranker and summary logs, in the same "Redis TLS upgrades" section of `docs/upgrades.md`. `AGENTS.md` places detailed upgrade procedures in dedicated guides, so `README.md` is not touched.

### D2. Version-neutral wording

The paragraph says "a Workspace runner image that includes the AGE-403 fix" and "when your release selects such an image". The existing historical paragraph (the original 0.2.8 rollout findings) stays: it is accurate as history and already tells the reader to check the selected images.

### D3. The `ssl_*` URL option

An operator can override `workspace.celeryBrokerUrl` and `workspace.celeryResultBackend` (`src/groundx/values.schema.json`, `workspace` object). A URL query option such as `ssl_cert_reqs=none` overrides the runner's verification settings, so the runner rejects any `ssl_*` option in a `rediss://` URL when it starts. The guide says so in one sentence so an operator who set one is not surprised by a pod that stops at startup.

### D4. Harness guidance

The matching `groundx-studio-harness` references change in a separate PR in that repository, as the on-prem repository guide requires when deployment behavior changes.
