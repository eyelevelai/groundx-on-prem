## MODIFIED Requirements

### Requirement: The note tells a private-CA operator what to do before upgrading

The note SHALL tell an operator whose Redis certificate comes from a private CA, or whose certificate does not cover the host name in `cache.existing`, to act **before** upgrading: build a complete CA bundle from the public root CAs plus the private CA, store it in a Secret under key `ca.crt` in the GroundX namespace (the `namespace` value, `eyelevel` by default) and set `fileAccess.caSecretName` to its name (or, when `fileAccess.caSecretName` is already set, add the Redis CA to that Secret's `ca.crt`), or correct `addr` to a host name the certificate covers. The first instruction SHALL say the bundle is complete, so no reader stores the private CA alone. It SHALL state that the bundle replaces the container's default CA file and that a private-CA-only Secret breaks HTTPS calls that rely on public roots. It SHALL state the failure an operator sees if they skip this and a certificate does not verify (ingest, search and summary requests fail and workers stop publishing and consuming), that the ai-server API and worker pods stay Ready even when they cannot connect, and that the operator should check the layout, ranker and summary logs for `certificate verify failed` after upgrading, and the `workspace-*` pod logs too when the selected Workspace image verifies Redis certificates. It SHALL NOT describe the CA mount as available on chart 0.2.7.

#### Scenario: The remedy and its ordering are stated (polarity: accept and enqueue)

- **GIVEN** an operator whose `rediss://` Redis uses a private-CA certificate
- **WHEN** they read the note before upgrading
- **THEN** it names the `ca.crt` Secret key, `fileAccess.caSecretName`, the corrected host name alternative, and "before upgrading"

#### Scenario: The bundle caveat is stated (polarity: finalize failure)

- **GIVEN** an operator who builds the CA Secret from only the Redis CA
- **WHEN** they read the note
- **THEN** it warns that the file replaces the default CA file and must include any public roots the pods still need, so that a CA file with only the private root is not presented as sufficient

#### Scenario: A 0.2.7 install is not told it has a CA mount (backward compatibility)

- **GIVEN** an operator on chart 0.2.7 who has not upgraded
- **WHEN** they read the note
- **THEN** the guidance is scoped to chart 0.2.8 and does not say a 0.2.7 install mounts `fileAccess.caSecretName`

#### Scenario: The Workspace pods are named in the post-upgrade check (polarity: reject before state)

- **GIVEN** an operator whose selected Workspace runner image verifies a `rediss://` Redis and whose certificate does not verify
- **WHEN** they read the post-upgrade check
- **THEN** it tells them to check the `workspace-*` pod logs for `certificate verify failed` as well as the layout, ranker and summary logs, so the failure is not looked for only in the ai-server pods

### Requirement: The note states which clients verify and which do not yet

The linked note SHALL preserve the chart 0.2.8 rollout findings for layout, ranker and summary verification, and identify the original extract client (AGE-395) and Workspace non-verification finding as historical. It SHALL state that a Workspace runner image that includes the AGE-403 fix verifies a `rediss://` broker and result backend, trusts a private CA through the same `SSL_CERT_FILE`, and stops at startup when a `workspace.celeryBrokerUrl` or `workspace.celeryResultBackend` URL sets an `ssl_*` option in its query. It SHALL state no release number for that image. It SHALL require checking the selected images rather than claiming either platform-wide verification or current non-verification without evidence.

#### Scenario: The unverified clients are named (polarity: skip unrelated repair path)

- **GIVEN** the same note
- **WHEN** a reader checks whether every Redis client now verifies
- **THEN** the note names the original extract client (AGE-395) and Workspace findings, scopes them to the historical rollout, and requires checking the selected images

#### Scenario: The Workspace runner fix is stated without a release number (polarity: finalize success)

- **GIVEN** the same note
- **WHEN** a reader checks whether the Workspace runner verifies a `rediss://` Redis
- **THEN** the note says a runner image that includes the AGE-403 fix verifies the broker and result backend, names the `ssl_*` URL option as rejected at startup, states no release or chart number for that image, and requires checking the selected image
