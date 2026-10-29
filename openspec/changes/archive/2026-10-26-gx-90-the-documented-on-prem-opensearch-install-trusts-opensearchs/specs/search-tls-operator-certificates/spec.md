## ADDED Requirements

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

### Requirement: GroundX trusts the operator OpenSearch CA through the GX-130 bundle
GroundX SHALL trust the chart-deployed OpenSearch through `fileAccess.caSecretName` (GX-130): the README SHALL tell the operator to put the CA that signed `node.crt` into that Secret's `ca.crt`, a complete bundle of the public root CAs plus that CA. The chart SHALL NOT add an OpenSearch-only CA value, mount or `ai.aws.search.caFile` setting.

Invariant: one CA setting serves every GroundX client, so a private CA is added in one place.

#### Scenario: No OpenSearch-only CA setting (polarity: reject before state; catches)
- **WHEN** `values.yaml`, `values.schema.json` and the rendered `config.yaml` are read
- **THEN** none of them contains `search.caSecretName` or `caFile`

#### Scenario: README routes OpenSearch trust to the bundle (polarity: accept and enqueue)
- **WHEN** the README `### OpenSearch` section is read
- **THEN** it names `fileAccess.caSecretName` as a complete bundle that includes the CA that signed `node.crt`

### Requirement: README documents operator-supplied OpenSearch certificates
The README `### OpenSearch` section SHALL: describe the demo-TLS risk of earlier installs; list the operator inputs (CA, node cert with SAN `<serviceName>-cluster-master.<namespace>.svc.cluster.local` and subject `CN=opensearch-node`, admin cert with subject `CN=gx-opensearch-admin`, a bcrypt hash for the admin user) with no certificate, key or hash value; create the `opensearch-tls` and `opensearch-internal-users` Secrets before OpenSearch starts; state that GroundX trusts the CA through the `fileAccess.caSecretName` bundle; describe restart-based rotation (a same-CA node certificate: update `opensearch-tls` and restart OpenSearch; a new CA: add it to the bundle and restart `groundx` and `process` before OpenSearch serves a certificate from it); and move "Upgrading an Existing Install" step 3 off `kirk.pem` to the operator admin certificate, add the CA to that bundle, set the OpenSearch credentials and remove the demo users before a final step that upgrades and restarts `groundx` and `process`.

#### Scenario: README carries no demo material and no secrets (polarity: reject before state)
- **WHEN** the README is read
- **THEN** `kirk.pem` and `kirk-key.pem` appear nowhere, and no `-----BEGIN` marker or bcrypt hash literal appears
- **AND** `fileAccess.caSecretName`, `opensearch-tls`, `opensearch-internal-users` and `CN=gx-opensearch-admin` are named
