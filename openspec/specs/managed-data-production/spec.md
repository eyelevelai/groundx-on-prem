# managed-data-production Specification

## Purpose
Isolated production storage with verified database TLS, scoped object and cache access, and confirmed lifecycle cleanup.

## Requirements

### Requirement: Isolated production managed storage

The operator SHALL activate production managed storage without changing existing
customer application bindings, existing credentials, or development allocations.

#### Scenario: Safe activation
- **WHEN** production storage is enabled
- **THEN** records, objects, and cache use production-specific permissions and namespaces
- **AND** database identity verification and encrypted cache connections remain mandatory
- **AND** existing development records and objects continue to work
- **AND** the unused development cache is removed after its dependency check

#### Scenario: Verified application lifecycle
- **WHEN** a disposable production application is published, restarted, taken offline, and republished
- **THEN** its durable records and files remain accessible through production application functions
- **AND** ordinary teardown preserves its runtime credentials
- **WHEN** that exact disposable application is permanently deleted with approval
- **THEN** its owned data, credentials, workloads, repository, and project metadata are removed
- **AND** unrelated applications and shared resources remain unchanged
