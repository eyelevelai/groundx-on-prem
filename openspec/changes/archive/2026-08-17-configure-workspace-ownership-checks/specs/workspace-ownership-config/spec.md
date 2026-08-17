## ADDED Requirements

### Requirement: Chart exposes workspace ownership checks

The chart SHALL expose a default-on boolean workspace ownership-check setting
and render it into every workspace runner process through the shared
`config.py`.

#### Scenario: Default remains enabled

- **GIVEN** Workspace is enabled and `workspace.ownershipChecksEnabled` is omitted
- **WHEN** the chart renders runner `config.py`
- **THEN** it contains `workspace_ownership_checks_enabled=True`.

#### Scenario: Operator disables checks

- **GIVEN** `workspace.ownershipChecksEnabled: false`
- **WHEN** the chart renders runner `config.py`
- **THEN** it contains `workspace_ownership_checks_enabled=False`.

#### Scenario: Schema rejects a non-boolean value

- **GIVEN** `workspace.ownershipChecksEnabled` is not a boolean
- **WHEN** Helm validates values against the strict schema
- **THEN** validation fails.

### Requirement: Rollout preserves compatibility

The compatible workspace-runner image SHALL be deployed before the chart
renders the new Python setting.

#### Scenario: Compatible rollout

- **GIVEN** the runner image accepts `workspace_ownership_checks_enabled`
- **WHEN** the chart upgrade changes the shared ConfigMap
- **THEN** the workspace API and all workers restart with the configured value.

#### Scenario: Rollback

- **WHEN** ownership enforcement must be restored
- **THEN** the operator sets the value to `true`
- **AND** no ownership data migration is required.
