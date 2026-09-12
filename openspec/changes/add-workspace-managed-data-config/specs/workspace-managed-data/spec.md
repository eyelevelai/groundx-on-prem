# Workspace managed-data configuration

## ADDED Requirements

### Requirement: Managed data is disabled by default

The chart SHALL keep Workspace managed data disabled unless an operator explicitly enables it.

#### Scenario: Existing values render unchanged

- **GIVEN** existing chart values
- **WHEN** the chart renders
- **THEN** Workspace settings disable managed data and require no provider configuration

### Requirement: Provider settings reach every Workspace process

The chart SHALL render the configured non-secret provider settings into the shared Workspace settings file.

#### Scenario: Enabled settings render

- **GIVEN** `workspace.managedData.enabled: true`
- **WHEN** the chart renders
- **THEN** the shared Workspace `config.py` contains the configured AWS region, environment-specific S3 buckets, Redis endpoints, and Redis user groups

### Requirement: Administrator credentials remain secret

The chart SHALL obtain RDS administrator URLs only from the existing Workspace Kubernetes Secret.

#### Scenario: RDS administrator URLs stay out of ConfigMaps

- **GIVEN** managed data is enabled
- **WHEN** the chart renders
- **THEN** no RDS administrator URL appears in a ConfigMap or committed values file
- **AND** Workspace pods obtain those URLs only from `workspace.existingSecret`

### Requirement: The deployment contract is strict and mirrored

The source and published chart surfaces SHALL expose the same strict managed-data values contract.

#### Scenario: Both chart surfaces validate

- **GIVEN** the new values
- **WHEN** schema validation and Helm tests run
- **THEN** the source and published chart surfaces accept the same block and render the same Workspace configuration
