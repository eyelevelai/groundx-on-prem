# search-tls-operator-certificates Specification

## Purpose
TBD - created by archiving change gx-90-the-documented-on-prem-opensearch-install-trusts-opensearchs. Update Purpose after archive.
## Requirements
### Requirement: The documented OpenSearch install trusts only operator-supplied certificates
`src/groundx/values/opensearch/values.yaml` (mirrored byte-identical to `helm/values/opensearch/values.yaml`) SHALL configure the upstream OpenSearch chart so that the CA, node certificate and node key are read from the operator-created Secret `opensearch-tls` (keys `ca.crt`, `node.crt`, `node.key`) mounted at `/usr/share/opensearch/config/certs`, the demo installer is disabled with `DISABLE_INSTALL_DEMO_CONFIG=true`, the admin identity is the DN `CN=gx-opensearch-admin`, and the admin user's credentials are read from the operator-created Secret `opensearch-internal-users` (key `internal_users.yml`). The seed file SHALL NOT contain `allow_unsafe_democertificates`, the DN `CN=kirk`, the demo file names (`esnode`, `root-ca.pem`), or any certificate or key material. The admin certificate and key SHALL NOT be mounted into the OpenSearch pod; only its DN is configured. The seed file SHALL pin the OpenSearch image to the sha256 digest tested with this configuration (`image.tag` ends in `@sha256:` and 64 hex digits).

Invariant: a certificate whose private key is public, and a user whose password hash is public, authenticate to nothing. Removing `allow_unsafe_democertificates` while leaving the image's shipped `internal_users.yml` (admin password `admin`) in effect does not satisfy it.

#### Scenario: Demo settings are absent (polarity: reject before state; catches)
- **WHEN** `config."opensearch.yml"` in the seed values file is read
- **THEN** it contains none of `allow_unsafe_democertificates`, `kirk`, `esnode`, `root-ca.pem`
- **AND** `extraEnvs` carries `DISABLE_INSTALL_DEMO_CONFIG` with value `true`

#### Scenario: Image-shipped demo users are replaced (polarity: reject before state; catches)
- **WHEN** the seed values file is read
- **THEN** `securityConfig.internalUsersSecret` names the operator Secret, so the image's `internal_users.yml` (admin password `admin`, plus demo users) is not the file the first security-index load reads

#### Scenario: Operator certificates are wired to every TLS listener (polarity: accept and enqueue; must not block)
- **WHEN** the seed values file is read
- **THEN** transport and HTTP `pemcert_filepath`, `pemkey_filepath` and `pemtrustedcas_filepath` point at `certs/node.crt`, `certs/node.key`, `certs/ca.crt`
- **AND** `plugins.security.authcz.admin_dn` is `CN=gx-opensearch-admin` and `plugins.security.restapi.roles_enabled` still lists `all_access`, so the GroundX application user can still be created through the REST API

#### Scenario: The OpenSearch image is pinned to a digest (polarity: reject before state; catches)
- **WHEN** the seed values file is read
- **THEN** `image.tag` ends in `@sha256:` followed by 64 hex digits, so a later push to the tag cannot change the image the install runs

#### Scenario: No key material is committed (polarity: reject before state; catches)
- **WHEN** the seed values file and its mirror are scanned
- **THEN** neither contains a PEM `-----BEGIN` marker

#### Scenario: Hand-synced files match their mirrors (polarity: reject before state; catches)
- **WHEN** `src/groundx/values/opensearch/values.yaml`, `values.yaml` and `values.schema.json` are compared with their `helm/` copies
- **THEN** each pair is byte-identical (`verify_mirrors()` through `MIRRORED_FILES` in `.build/bin/verify-storage-contract.py`)

#### Scenario: The published opensearch wrapper chart uses the same configuration (polarity: reject before state; catches)
- **WHEN** the `operator` block of `src/opensearch/values.yaml`, which `src/build.sh` packages and publishes as the `opensearch` chart, is read
- **THEN** it passes the same checks as the seed values file, so a wrapper install also runs on operator certificates and operator-supplied users

### Requirement: GroundX trusts the in-cluster OpenSearch through opensearch-tls by default
When GroundX uses the in-cluster OpenSearch (`groundx.search.create` is true: no `search.existing.url` and `mode` is not `ingest`) and `search.caSecretName` is empty, the chart SHALL use the `opensearch-tls` Secret, which holds the CA that signed `node.crt`: it SHALL mount only its `ca.crt` key read-only at `/var/run/groundx/search-ca` on the Golang workloads and render `ai.aws.search.caFile: /var/run/groundx/search-ca/ca.crt`. No CA bundle is required, and the chart SHALL render without `fileAccess.caSecretName`. An existing OpenSearch and ingest mode SHALL render neither the mount nor `caFile`.

Invariant: the operator creates `opensearch-tls` for OpenSearch to start, so GroundX trusts OpenSearch without a separate CA step; `groundx` and `process` images from 0.3.0 or later read `caFile`.

#### Scenario: The default install trusts opensearch-tls (polarity: accept and enqueue; must not block)
- **WHEN** the chart renders with default search settings, `search.caSecretName` empty and `fileAccess.caSecretName` empty
- **THEN** the render succeeds, `config.yaml` carries `caFile: /var/run/groundx/search-ca/ca.crt` under `ai.aws.search`, and `groundx`, `process` and `queue` mount `ca.crt` from `opensearch-tls` read-only through the shared `groundx.caBundle.mount` helper (`src/groundx/tests/search_ca_test.yaml` checks `groundx`)

#### Scenario: An existing OpenSearch or ingest mode gets no search CA (polarity: skip unrelated repair path; must not block)
- **WHEN** the chart renders with either `search.existing.url` set or `mode: ingest`
- **THEN** `config.yaml` carries no `caFile` and no workload mounts `search-ca`

### Requirement: An optional OpenSearch CA Secret replaces opensearch-tls
When `search.caSecretName` is set, the chart SHALL mount that Secret's `ca.crt` instead of `opensearch-tls`, for OpenSearch only. `docs/upgrades.md` SHALL describe it as optional, together with the `fileAccess.caSecretName` bundle that `groundx` and `process` images from 0.2.8 to 0.2.9 use instead of `caFile`.

Invariant: a service setting takes precedence over the default when it is set.

#### Scenario: The override replaces the default Secret (polarity: accept and enqueue)
- **WHEN** the chart renders with `search.caSecretName` set
- **THEN** the `search-ca` volume names that Secret instead of `opensearch-tls`

#### Scenario: README describes no CA step (polarity: reject before state; catches)
- **WHEN** the README is read
- **THEN** it names neither `fileAccess.caSecretName` nor `search.caSecretName`

### Requirement: README documents operator-supplied OpenSearch certificates
The README `### OpenSearch` section, together with the `## OpenSearch` section of `docs/upgrades.md`, which it links for installation detail, upgrading an existing install, rotation, the OpenSearch-only CA and certificate errors, SHALL: describe the demo-TLS risk of earlier installs; list the operator inputs (CA, node cert with SAN `<serviceName>-cluster-master.<namespace>.svc.cluster.local` and subject `CN=opensearch-node`, admin cert with subject `CN=gx-opensearch-admin`, a bcrypt hash for the admin user) with no certificate, key or hash value; create the `opensearch-tls` and `opensearch-internal-users` Secrets before OpenSearch starts; state that GroundX trusts the CA in `opensearch-tls`, or in `search.caSecretName` when it is set, and that images older than 0.3.0 need the `fileAccess.caSecretName` bundle instead; point the fix-forward recovery after a failed GroundX upgrade at the Secret GroundX uses for OpenSearch (`search.caSecretName` when set, otherwise `opensearch-tls`, or the bundle with images older than 0.3.0); give the exact upgrade of a release installed from the published `opensearch` wrapper chart (`groundx/opensearch` 0.1.1 to 0.1.2, the two Secrets first, the operator's changed settings under `operator:` without `config`, `extraEnvs`, `secretMounts`, `securityConfig`, `image` or `majorVersion`); describe restart-based rotation (a same-CA node certificate: update `opensearch-tls` and restart OpenSearch; a new CA: add it, keeping the old one, to the CA GroundX trusts for OpenSearch (`opensearch-tls`, `search.caSecretName` when set, or the bundle with images older than 0.3.0) and restart `groundx` and `process` before OpenSearch serves a certificate from it, reissue the operator admin certificate from the new CA, and remove the old CA from that Secret, from the bundle only once nothing else trusted through it uses it); and move "Upgrading an Existing Install" step 3 off `kirk.pem` to the operator admin certificate, choose images from 0.3.0 or later (or add the CA to the bundle for older images), set the OpenSearch credentials and remove the demo users before a final step that upgrades and restarts `groundx` and `process`. The upgrade SHALL start with a version check on every OpenSearch pod: 2.19.0 to 3.2.0 upgrades to the pinned 3.2.0; below 2.19 is re-certified without changing the version, by keeping the running image (`global.dockerRegistry`, `image`) in the overrides file; above 3.2.0 stops.

#### Scenario: README carries no demo material and no secrets (polarity: reject before state)
- **WHEN** the README is read
- **THEN** `kirk.pem` and `kirk-key.pem` appear nowhere, and no `-----BEGIN` marker or bcrypt hash literal appears
- **AND** `opensearch-tls`, `opensearch-internal-users` and `CN=gx-opensearch-admin` are named
