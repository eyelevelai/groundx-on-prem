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

### Requirement: Private extraction uses the gateway bucket
When extraction and file access are enabled, the chart SHALL reject an effective extraction bucket that differs from the configured file gateway bucket. It SHALL preserve inherited and explicitly matching buckets without changing rendered configuration for valid deployments.

#### Scenario: Separate private extraction bucket
- **GIVEN** extraction and file access are enabled and `extract.file.bucketName` differs from `file.bucketName`
- **WHEN** either chart surface renders
- **THEN** rendering fails before private extraction output can become inaccessible through the gateway, extraction API and native sharing.

#### Scenario: Matching extraction bucket
- **GIVEN** extraction and file access are enabled and the extraction bucket is inherited or explicitly matches `file.bucketName`
- **WHEN** either chart surface renders
- **THEN** its existing extraction configuration is preserved.

#### Scenario: Separate bucket without enabled protection or extraction
- **GIVEN** `extract.file.bucketName` differs from `file.bucketName` and file access or extraction is disabled
- **WHEN** either chart surface renders
- **THEN** the unused gateway bucket constraint does not change the existing deployment behavior.

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

### Requirement: Native ingress cannot bypass delivery authorization
The chart SHALL reject legacy native store ingress using the public delivery host or an enabled chart gateway host whenever file access is enabled. It SHALL resolve templated ingress hostnames as the ingress renderer does and SHALL permit separate native signing/store routes.

#### Scenario: External gateway and templated native ingress collision
- **GIVEN** file access is enabled, its chart ingress is disabled and a legacy native ingress hostname expands to the public delivery host
- **WHEN** either chart surface renders
- **THEN** rendering fails before a native storage route can bypass the gateway.

#### Scenario: Separate native signing route
- **GIVEN** file access is enabled and native ingress uses a distinct signing hostname
- **WHEN** managed or external gateway ingress renders
- **THEN** the native storage backend, TLS and route paths remain available.

#### Scenario: Disabled unused gateway hostname names the native signing route
- **GIVEN** file access is enabled, chart gateway ingress is disabled and its unused hostname matches a distinct native signing/store ingress
- **WHEN** either chart surface renders
- **THEN** the native route remains available without changing public delivery routing.

#### Scenario: Native ingress Service port differs from private HTTPS origin
- **GIVEN** file access is enabled, the private HTTPS origin uses port 443 or 9443 and the native MinIO Service uses port 9000
- **WHEN** either chart surface renders a generated native signing ingress backend
- **THEN** that backend targets Service port 9000 for both supported Ingress API shapes
- **AND** storage dependency checks and client configuration retain the private origin's host and port.

#### Scenario: Native port compatibility
- **GIVEN** disabled file access, existing external storage or explicit custom native ingress paths
- **WHEN** either chart surface renders
- **THEN** existing port resolution and explicit custom backends are preserved.

### Requirement: Feature credentials reach only storage consumers
The chart SHALL import the feature storage Secret only into verified Go, migration, layout and extraction consumers. Explicit operator global and workload Secret imports SHALL retain their existing scope.

#### Scenario: Storage consumers without dependency wait containers
- **GIVEN** file access has a storage Secret and no operator global Secrets
- **WHEN** workloads render
- **THEN** the gateway, upload and other Go storage clients, migration hook, layout and extraction receive that Secret
- **AND** ranker API/inference, summary API/inference, workspace and metrics do not.

#### Scenario: Operator global Secret and ambient AWS credentials
- **GIVEN** an explicit operator global Secret or native S3 with an empty feature storage Secret
- **WHEN** workloads render
- **THEN** operator global imports remain available to every workload, duplicate imports are absent and ambient S3 creates no empty Secret reference.
