# existing-redis-tls-upgrade-guidance Specification

## Purpose
TBD - created by archiving change gx-131-ai-server-enforce-redis-tls-verification-and-refresh. Update Purpose after archive.
## Requirements
### Requirement: The existing-Redis section carries a chart 0.2.8 verified-TLS upgrade note

`README.md` SHALL carry, inside "Using an Existing Redis Cluster" and before "Deploying a Dedicated Redis Cluster", a `####` upgrade note titled "Upgrading to Chart 0.2.8 with a `rediss://` Redis". It SHALL state that chart 0.2.8 ai-server images (the layout, ranker and summary services, APIs and workers) verify the certificate chain and host name of a `rediss://` Redis, that this applies when `ssl: true` is set under `cache.existing`, under the ranker-only `ranker.cache`, or under `cache.metrics.existing` for a separate metrics Redis, and the certificate must cover the `addr` host name of each, and that plain `redis://`, including the Redis the chart installs, is unaffected. It SHALL state that a certificate chaining to a public root needs no action. It SHALL NOT document any setting that turns verification off.

#### Scenario: The note states the behavior change and who is unaffected (polarity: finalize success)

- **GIVEN** the README on this branch
- **WHEN** a reader opens the note under "Using an Existing Redis Cluster"
- **THEN** it says chart 0.2.8 images verify chain and host name for `rediss://`, that plain `redis://` and the bundled Redis are unaffected, and that a publicly rooted certificate needs no action

#### Scenario: The note offers no way to skip verification (polarity: reject before state)

- **GIVEN** the same note
- **WHEN** a reader looks for a setting that disables verification
- **THEN** none is documented; the only remedies named are supplying the CA or correcting the host name, and the opposite outcome (a documented `ssl_cert_reqs=none` or equivalent toggle) does not appear

### Requirement: The note tells a private-CA operator what to do before upgrading

The note SHALL tell an operator whose Redis certificate comes from a private CA, or whose certificate does not cover the host name in `cache.existing`, to act **before** upgrading: build a complete CA bundle from the public root CAs plus the private CA, store it in a Secret under key `ca.crt` in the GroundX namespace (the `namespace` value, `eyelevel` by default) and set `fileAccess.caSecretName` to its name (or, when `fileAccess.caSecretName` is already set, add the Redis CA to that Secret's `ca.crt`), or correct `addr` to a host name the certificate covers. The first instruction SHALL say the bundle is complete, so no reader stores the private CA alone. It SHALL state that the bundle replaces the container's default CA file and that a private-CA-only Secret breaks HTTPS calls that rely on public roots. It SHALL state the failure an operator sees if they skip this and a certificate does not verify (ingest, search and summary requests fail and workers stop publishing and consuming), that the ai-server API and worker pods stay Ready even when they cannot connect, and that the operator should check the layout, ranker and summary logs for `certificate verify failed` after upgrading. It SHALL NOT describe the CA mount as available on chart 0.2.7.

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

### Requirement: The note states which clients verify and which do not yet

The note SHALL state that the ai-server layout, ranker and summary clients verify, and that the extract client (AGE-395) and the workspace runner still accept any certificate from a `rediss://` Redis, so an operator does not assume the whole platform verifies.

#### Scenario: The unverified clients are named (polarity: skip unrelated repair path)

- **GIVEN** the same note
- **WHEN** a reader checks whether every Redis client now verifies
- **THEN** the note names the extract client (AGE-395) and the workspace runner as still not verifying, and does not claim platform-wide verification

### Requirement: The change touches the README only

The change SHALL NOT modify any template, values file, schema, snapshot or `helm/` mirror file.

#### Scenario: Nothing outside the README changes (polarity: reject before state)

- **GIVEN** the branch diff against its merge base with `origin/0.2.8`
- **WHEN** the changed paths under `src/`, `helm/`, `.build/` and `helm-releases/` are listed
- **THEN** the list is empty and `README.md` is the only changed repo file outside `openspec/`

