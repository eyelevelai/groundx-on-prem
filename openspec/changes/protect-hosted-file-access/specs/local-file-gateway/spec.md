## ADDED Requirements

### Requirement: Optional local gateway deployment
The chart SHALL preserve disabled legacy behavior and SHALL deploy local file authorization without an AWS dependency when enabled.

#### Scenario: Disabled existing installation
- **GIVEN** no fileAccess values
- **WHEN** the chart renders
- **THEN** existing storage/configuration/ingress behavior is preserved.

#### Scenario: Endpoint loop
- **GIVEN** an enabled gateway whose storage or signing endpoint names the public delivery host or an enabled fileAccess ingress hostname
- **WHEN** configuration is admitted
- **THEN** admission fails rather than routing worker reads recursively.

#### Scenario: Extraction SDK silently ignores private fields
- **GIVEN** file access is enabled and an installed extraction SDK lacks `public_read` or `storage_endpoint`
- **WHEN** generated configuration executes
- **THEN** it raises a safe compatibility error before constructing settings, storage clients or buckets
- **AND** public configuration with file access disabled retains its existing initialization.

#### Scenario: Native sharing route
- **GIVEN** a reachable native S3 API and protected resource
- **WHEN** a standard share URL is returned
- **THEN** Host/path/query are unchanged and storage validates its signature independently of GroundX or S4 web UI auth.

### Requirement: Proven store compatibility and private origins
An enabled deployment SHALL verify private origins, TLS and at-rest encryption and SHALL claim compatibility only for observed passing store versions.

#### Scenario: Existing public bucket grant
- **GIVEN** anonymous store reads bypass the gateway
- **WHEN** protection activation is attempted
- **THEN** it remains unavailable until operator closure and readback pass.

#### Scenario: S4 deployment
- **GIVEN** pinned S4 chart and image with native S3 port 7480
- **WHEN** the integration suite runs
- **THEN** support requires passing native signed reads/writes and expiry, and the one-replica storage availability limit is recorded.

### Requirement: Local support releases are independent
Local store support SHALL require the selected backend's passing exact-version integration and SHALL not gate hosted cloud activation on other vendor certification.

#### Scenario: MinIO verified and S4 outstanding
- **GIVEN** passing MinIO local gates and incomplete S4 tests
- **WHEN** local MinIO or hosted cloud release is evaluated
- **THEN** S4 remains unadvertised and its outstanding work does not block those independently verified releases.
