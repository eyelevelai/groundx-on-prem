## ADDED Requirements

### Requirement: The documented OpenSearch install trusts only operator-supplied certificates
`src/groundx/values/opensearch/values.yaml` (mirrored byte-identical to `helm/values/opensearch/values.yaml`) SHALL configure the upstream OpenSearch chart so that the CA, node certificate and node key are read from the operator-created Secret `opensearch-tls` (keys `ca.crt`, `node.crt`, `node.key`) mounted at `/usr/share/opensearch/config/certs`, the demo installer is disabled with `DISABLE_INSTALL_DEMO_CONFIG=true`, the admin identity is the DN `CN=gx-opensearch-admin`, and the admin user's credentials are read from the operator-created Secret `opensearch-internal-users` (key `internal_users.yml`). The seed file SHALL NOT contain `allow_unsafe_democertificates`, the DN `CN=kirk`, the demo file names (`esnode`, `root-ca.pem`), or any certificate or key material. The admin certificate and key SHALL NOT be mounted into the OpenSearch pod; only its DN is configured.

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

#### Scenario: No key material is committed (polarity: reject before state; catches)
- **WHEN** the seed values file and its mirror are scanned
- **THEN** neither contains a PEM `-----BEGIN` marker

#### Scenario: Hand-synced files match their mirrors (polarity: reject before state; catches)
- **WHEN** `src/groundx/values/opensearch/values.yaml`, `values.yaml` and `values.schema.json` are compared with their `helm/` copies
- **THEN** each pair is byte-identical (`verify_mirrors()` through `MIRRORED_FILES` in `.build/bin/verify-storage-contract.py`)

### Requirement: The GroundX chart takes an operator search CA and fails closed without one
The chart SHALL accept `search.caSecretName` (string, default empty, in `values.yaml` and `values.schema.json`) naming a Secret in the release namespace whose key `ca.crt` is the CA that signed the OpenSearch server certificate. When the chart deploys against the in-cluster OpenSearch (`groundx.search.create` is true) and `search.caSecretName` is empty, rendering SHALL fail with a message naming `search.caSecretName`. When `search.existing.url` is set, `mode` is `ingest`, or search is disabled, an empty value SHALL render without error. The check runs wherever the GX-75 password check runs, so it does not depend on a Golang service being rendered.

Invariant: the chart never renders a GroundX config that talks to the chart-deployed OpenSearch with no CA to verify it against; an unset CA is rejected, not defaulted to skipping verification.

#### Scenario: In-cluster OpenSearch without a CA fails the render (polarity: reject before state; catches)
- **WHEN** the chart is rendered with `mode` not `ingest`, no `search.existing.url`, valid search passwords and `search.caSecretName` empty
- **THEN** the render fails naming `search.caSecretName`
- **AND** no `config-yaml-map` Secret is produced

#### Scenario: Existing OpenSearch without a CA renders (polarity: accept and enqueue; must not block; backward compatibility during rollout)
- **WHEN** the chart is rendered with `search.existing.url` set and `search.caSecretName` empty
- **THEN** the render succeeds and `ai.aws.search` has no `caFile` line

#### Scenario: Ingest mode needs no CA (polarity: accept and enqueue; must not block)
- **WHEN** the chart is rendered with `mode: ingest` and `search.caSecretName` empty
- **THEN** the render succeeds

### Requirement: The search CA is mounted read-only into every Golang workload and rendered as caFile
When `search.caSecretName` is set, every Deployment rendered by `templates/app/golang.yaml` SHALL mount that Secret's `ca.crt` read-only at `/var/run/groundx/search-ca/ca.crt` (volume and mount named `search-ca`), and `config.yaml` SHALL render `ai.aws.search.caFile: /var/run/groundx/search-ca/ca.crt`. The key serves both the chart-deployed OpenSearch and a private-CA `search.existing`. When it is empty, no volume, mount or `caFile` line SHALL be rendered. Only `groundx` and `process` images that read `caFile` verify the server certificate; older images ignore the key.

#### Scenario: CA is mounted and rendered (polarity: accept and enqueue)
- **WHEN** the chart is rendered with `search.caSecretName: fixture-search-ca`
- **THEN** the `groundx`, `process` and `queue` Deployments each carry a `search-ca` volume from that Secret (item `ca.crt`) and a read-only mount at `/var/run/groundx/search-ca`
- **AND** `config.yaml` carries `caFile: /var/run/groundx/search-ca/ca.crt` under `ai.aws.search`

#### Scenario: Private-CA existing OpenSearch uses the same key (polarity: accept and enqueue)
- **WHEN** the chart is rendered with `search.existing.url` and `search.caSecretName` both set
- **THEN** `caFile` is rendered and the CA is mounted

#### Scenario: Unset CA renders no mount (polarity: skip unrelated repair path; backward compatibility during rollout)
- **WHEN** the chart is rendered with `search.existing.url` set and no `search.caSecretName`
- **THEN** no Deployment carries a `search-ca` volume or mount and `config.yaml` has no `caFile`

### Requirement: Every render gate supplies a test-only search CA
`tests/files/values.search-credentials.yaml` and every helm-unittest suite that sets `search.privilegedPassword` SHALL also set `search.caSecretName` to a test-only Secret name so existing renders pass the guard. Snapshots changed by the new volume, mount or `caFile` SHALL be hand-patched and verified without `-u`.

#### Scenario: Existing suites still pass (polarity: accept and enqueue; must not block)
- **WHEN** the helm-unittest suites run with the updated fixtures
- **THEN** all pass without regenerating any snapshot

### Requirement: README documents operator-supplied OpenSearch certificates
The README `### OpenSearch` section SHALL: describe the demo-TLS risk of earlier installs; list the operator inputs (CA, node cert with SAN `<serviceName>-cluster-master.<namespace>.svc.cluster.local` and subject `CN=opensearch-node`, admin cert with subject `CN=gx-opensearch-admin`, a bcrypt hash for the admin user) with no certificate, key or hash value; create the `opensearch-tls` and `opensearch-internal-users` Secrets before OpenSearch starts; state `search.caSecretName` and the image requirement; describe restart-based rotation (restart OpenSearch, then `groundx`, then `process`); and move "Upgrading an Existing Install" step 3 off `kirk.pem` to the operator admin certificate, adding a pre-upgrade step to set `search.caSecretName` and re-certify `groundx` and `process`.

#### Scenario: README carries no demo material and no secrets (polarity: reject before state)
- **WHEN** the README is read
- **THEN** `kirk.pem` and `kirk-key.pem` appear nowhere, and no `-----BEGIN` marker or bcrypt hash literal appears
- **AND** `search.caSecretName`, `opensearch-tls`, `opensearch-internal-users` and `CN=gx-opensearch-admin` are named
