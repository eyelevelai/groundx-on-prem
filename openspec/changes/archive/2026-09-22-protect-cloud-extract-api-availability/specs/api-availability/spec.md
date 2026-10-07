# API availability

## ADDED Requirements

### Requirement: Every API exposes the same opt-in disruption budget

The chart SHALL expose an optional disruption budget for `groundx`, `extract-api`, `layout-api`, `ranker-api`, `summary-api`, and `workspace-api` through each service's values and settings helper.

#### Scenario: An API budget is enabled

- **GIVEN** any supported API is enabled
- **AND** its disruption budget is enabled
- **WHEN** Helm renders the chart
- **THEN** one PodDisruptionBudget is rendered for that API
- **AND** it requires one available pod
- **AND** its selector matches the API Deployment

### Requirement: Generic deployments retain existing availability defaults

The chart SHALL keep all API disruption budgets disabled and replica defaults unchanged unless an operator opts in.

#### Scenario: Default chart render

- **GIVEN** the default chart values
- **WHEN** Helm renders the chart
- **THEN** no API disruption budget is rendered
- **AND** the extract API replica default remains one

### Requirement: Hosted production preserves redundant APIs during voluntary eviction

The hosted EKS deployment SHALL protect each enabled API that already has at least two minimum replicas.

#### Scenario: Hosted production render

- **GIVEN** `values.ranker-only-eks.yaml`
- **WHEN** Helm renders either chart surface
- **THEN** the extract API Deployment requests two replicas
- **AND** its HPA minimum is two
- **AND** its PodDisruptionBudget has `minAvailable: 1`
- **AND** `ranker-api` remains absent in ingest-only mode
- **AND** single-replica APIs do not render a budget

### Requirement: The deployment contract is strict and mirrored

The source and published chart surfaces SHALL expose and render the same API disruption-budget contract.

#### Scenario: Both chart surfaces validate

- **GIVEN** the disruption-budget values
- **WHEN** schema, unit, lint, and render validation run
- **THEN** both chart surfaces accept and render the same API budgets
