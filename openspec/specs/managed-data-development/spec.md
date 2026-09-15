# managed-data-development Specification

## Purpose
Enable development-only managed application storage through the existing Workspace
service, with verified database encryption and no changes to customer data or shared
infrastructure boundaries.

## Requirements

### Requirement: Development verification preserves existing customer apps

The rollout SHALL update the existing Workspace service and its API callers,
retaining their existing GitHub connection, metadata database, and queues.
It SHALL allocate managed data only for disposable projects using development
storage. Existing customer app deployments and data bindings, shared IAM policies,
and shared cluster networking SHALL remain unchanged.

#### Scenario: Existing services are updated

- **WHEN** the verified rollout is applied
- **THEN** only the named Workspace and API services and development prerequisites change
- **AND** no existing customer app data is migrated or deleted
- **AND** failure restores prior service versions without deleting durable data

### Requirement: Database access requires verified encryption when configured

The runner SHALL support CA-file settings requiring encryption, trusted
certificates, and hostname verification for metadata and managed administration.
New managed application database URLs SHALL retain this verification in the
existing server-side secret binding. Unconfigured paths SHALL retain driver defaults.

#### Scenario: Development database accepts verified TLS

- **WHEN** the runner connects using the trusted CA and the exact database hostname
- **THEN** both production connection functions complete an encrypted read-only query
- **AND** the unchanged scaffold database constructor accepts the generated URL

#### Scenario: An unsafe endpoint is presented

- **WHEN** the CA is missing, the certificate is untrusted, the hostname differs, or the server has no TLS
- **THEN** the connection fails before sending database authentication
- **AND** no unencrypted fallback occurs

### Requirement: Incomplete prerequisites prevent rollout claims

The rollout SHALL NOT claim completed application readiness from a successful
connection, container build, or namespace creation. It SHALL defer paid storage
when missing access or an unresolved isolation boundary prevents its use.

#### Scenario: Existing publishing credentials are unavailable

- **WHEN** the existing runner cannot use its GitHub connection
- **THEN** deployment and lifecycle tests remain incomplete
- **AND** paid storage is deferred until the connection works

#### Scenario: Namespace networking is not isolated

- **WHEN** network-policy enforcement is disabled on the shared cluster
- **THEN** the namespace is not described as network-isolated
- **AND** project isolation is tested through database roles, S3 permissions, and Redis ACLs
