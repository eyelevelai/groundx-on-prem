# Extract API availability

## ADDED Requirements

### Requirement: Generic deployments retain existing availability defaults

The chart SHALL keep the extract API disruption budget disabled and its replica defaults unchanged unless an operator opts in.

#### Scenario: Default chart render

- **GIVEN** the default chart values
- **WHEN** Helm renders the chart
- **THEN** no extract API disruption budget is rendered
- **AND** the extract API replica default remains one

### Requirement: Hosted production preserves an extract API during voluntary eviction

The hosted EKS deployment SHALL run at least two extract API replicas with a PodDisruptionBudget requiring one available replica.

#### Scenario: Hosted production render

- **GIVEN** `values.ranker-only-eks.yaml`
- **WHEN** Helm renders either chart surface
- **THEN** the extract API Deployment requests two replicas
- **AND** its HPA minimum is two
- **AND** its PodDisruptionBudget has `minAvailable: 1`

### Requirement: The deployment contract is strict and mirrored

The source and published chart surfaces SHALL expose and render the same disruption-budget contract.

#### Scenario: Both chart surfaces validate

- **GIVEN** the disruption-budget values
- **WHEN** schema, unit, lint, and render validation run
- **THEN** both chart surfaces accept and render the same extract API budget
