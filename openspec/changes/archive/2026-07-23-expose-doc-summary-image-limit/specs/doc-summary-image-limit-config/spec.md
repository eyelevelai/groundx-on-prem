## ADDED Requirements

### Requirement: Chart exposes document summary maxImages config

The chart SHALL allow operators to configure the app's document-summary page
image limit through the existing engine values surface.

#### Scenario: Operator sets maxImages

- **GIVEN** values include `engines.default.maxImages: 30`
- **WHEN** the chart renders application `config.yaml`
- **THEN** the rendered `engines.default` config contains `maxImages: 30`.

#### Scenario: Operator omits maxImages

- **GIVEN** values do not include `engines.default.maxImages`
- **WHEN** the chart renders the default engine config
- **THEN** the rendered config does not include `maxImages`
- **AND** the app runtime default remains responsible for the default limit.

#### Scenario: Operator sets maxImages to null

- **GIVEN** values include `engines.default.maxImages: null`
- **WHEN** the chart renders the default engine config
- **THEN** the rendered config does not include `maxImages`
- **AND** the app runtime default remains responsible for the default limit.

### Requirement: Schema permits maxImages

The chart SHALL accept `engines.default.maxImages` under strict values schema
validation.

#### Scenario: Helm validates values with maxImages

- **GIVEN** values include `engines.default.maxImages`
- **WHEN** Helm validates the chart values schema
- **THEN** validation succeeds.

#### Scenario: Helm validates values with null maxImages

- **GIVEN** values include `engines.default.maxImages: null`
- **WHEN** Helm validates the chart values schema
- **THEN** validation succeeds.

#### Scenario: Helm rejects non-positive maxImages

- **GIVEN** values include `engines.default.maxImages: 0`
- **WHEN** Helm validates the chart values schema
- **THEN** validation fails because maxImages must be greater than or equal to 1.

#### Scenario: Helm rejects non-integer maxImages

- **GIVEN** values include `engines.default.maxImages: many`
- **WHEN** Helm validates the chart values schema
- **THEN** validation fails because maxImages must be an integer or null.

### Requirement: Config exposure does not change deployment topology

The chart SHALL expose the app config without changing Kubernetes resources.

#### Scenario: Chart renders with maxImages

- **WHEN** the chart renders with `engines.default.maxImages`
- **THEN** no new pod, service, queue, PVC, RBAC resource, HPA, or stateful
  resource is created for this feature.

### Requirement: Runtime fix remains owned by cashbot-go

The chart SHALL not claim to enforce image limits by itself.

#### Scenario: Chart renders maxImages before compatible app image is deployed

- **GIVEN** the chart renders `engines.default.maxImages`
- **AND** the deployed app image does not consume that config key
- **WHEN** a long document is summarized
- **THEN** the chart alone is not considered a complete fix for FRA-76.
