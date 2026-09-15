## ADDED Requirements

### Requirement: Isolated credential cleanup rollout

The rollout SHALL update managed app uninstall workflows before deploying the runner
purge caller. It SHALL preserve unrelated workloads, configuration, and customer data.

#### Scenario: Runner update
- **WHEN** the latest Helm release is stable and app workflows support purge
- **THEN** only the six Workspace images change to the verified merged runner digest
- **AND** their API and worker readiness are verified

#### Scenario: Disposable app lifecycle
- **WHEN** the disposable development app is taken offline
- **THEN** its credentials remain available for republish
- **WHEN** that app is permanently deleted with confirmed identity
- **THEN** its runtime Secret, workloads, repository, and metadata are absent
- **AND** unrelated credentials and shared infrastructure remain unchanged
