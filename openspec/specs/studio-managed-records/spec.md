# studio-managed-records Specification

## Purpose
Host new managed production records on the Studio database while preserving existing clients and other storage.

## Requirements

### Requirement: Studio production records use the Studio cluster
New managed production records SHALL use groundx-studio without changing existing app credentials, development storage, production objects or cache, or core service database settings.

#### Scenario: Safe switch
- **GIVEN** no production managed-record allocations exist
- **WHEN** the production connection changes and Workspace restarts
- **THEN** the real provider can allocate, write, read, and delete an isolated Studio schema while app access to unrelated schemas is denied

#### Scenario: Existing client preservation
- **GIVEN** Sterling and the verified operator address use groundx-studio
- **WHEN** the cluster receives its dedicated security group
- **THEN** both allowed connection paths work and broad internet rules are absent from that cluster's groups

#### Scenario: App lifecycle
- **GIVEN** a private disposable app has managed production records, objects, and cache
- **WHEN** its middleware restarts and ordinary teardown is followed by republication
- **THEN** all stored values remain readable and runtime credentials are unchanged
- **WHEN** the disposable project is permanently deleted
- **THEN** its storage allocations, app resources, repository, and credentials are removed without changing Sterling
