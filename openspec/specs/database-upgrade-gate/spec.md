# database-upgrade-gate Specification

## Purpose
Run database migrations before Helm replaces Go workloads, preserving existing application resources when migration fails.

## Requirements
### Requirement: Database upgrade precedes application replacement
The chart SHALL run the target GroundX migration command before upgrading Go workloads.

#### Scenario: Upgrade with API or workers
- **GIVEN** at least one Go workload is enabled
- **WHEN** Helm upgrades the release
- **THEN** the target-config Secret and migration Job run before application replacement

#### Scenario: Failed migration
- **GIVEN** the migration Job fails
- **WHEN** Helm processes the pre-upgrade hook
- **THEN** regular resources are not upgraded and failed hook diagnostics remain available

### Requirement: Fresh installs and isolated services remain supported
The chart SHALL preserve fresh-install ordering and avoid creating migration work for deployments without Go workloads.

#### Scenario: Fresh database
- **GIVEN** a new installation with chart-managed database
- **WHEN** Helm installs the release
- **THEN** no pre-install migration hook blocks backing-service creation

#### Scenario: Worker-only upgrade
- **GIVEN** GroundX API is disabled and a Go ingestion worker is enabled
- **WHEN** Helm upgrades the release
- **THEN** the migration hook still protects that worker

### Requirement: Migration uses the target deployment configuration
The migration Job SHALL use the GroundX image and database configuration without depending on search, Redis, queues or workspace services.

#### Scenario: Image and security overrides
- **GIVEN** custom image, service account, security, scheduling and credential references
- **WHEN** the upgrade Job renders
- **THEN** the relevant GroundX settings are preserved, its configuration is isolated from running pods, and its labels cannot select it as an API endpoint
