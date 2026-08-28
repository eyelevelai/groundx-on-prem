# Anthropic workflow engine service

## ADDED Requirements

### Requirement: Anthropic is an external model service

The chart MUST preserve exact `serviceType: anthropic` and configure it as an external
provider for summary and extraction-agent workloads.

#### Scenario: Summary selects Anthropic

- **Given** summary existing-service or per-engine values select `anthropic`
- **When** the chart renders application configuration
- **Then** the exact service, supplied summary URL or engine base URL, and engine ID
  are rendered
- **And** no in-cluster summary endpoint or model is substituted

#### Scenario: Per-engine service uses the schema field

- **Given** `engines.<name>.service` is `anthropic`
- **When** the chart renders application configuration
- **Then** that engine's service is exactly `anthropic`
- **And** the renderer does not ignore the schema field in favor of the summary default

#### Scenario: Extraction agent selects Anthropic

- **Given** extraction-agent values select `anthropic`
- **When** the chart renders application configuration
- **Then** the exact service, supplied endpoint, and supplied model are rendered
- **And** no in-cluster endpoint, model, kwargs, or reasoning default is substituted

### Requirement: Anthropic uses explicit provider credentials

The chart MUST require an existing supported provider-credential source for Anthropic
and MUST NOT fall back to the GroundX admin API key.

#### Scenario: Existing credential sources work

- **Given** Anthropic is selected with a supported summary or extraction credential
  source
- **When** the chart renders
- **Then** it passes that source through the existing credential contract
- **And** it does not substitute the GroundX admin API key

#### Scenario: Credential is missing

- **Given** Anthropic is selected without a supported provider credential
- **When** the chart renders
- **Then** rendering fails with a configuration error
- **And** the admin API key is not used

### Requirement: Existing providers remain stable

The chart MUST retain the current rendered behavior for every existing service value
and for deployments that do not select Anthropic.

#### Scenario: Existing service regression suite

- **Given** the existing service fixtures and default values
- **When** the full Helm validation gate runs
- **Then** their provider routing and credential behavior remain unchanged

### Requirement: Chart and runtime support are released together

The chart MUST NOT advertise or release Anthropic configuration with an application
image that lacks the matching native provider adapter.

#### Scenario: Release is prepared

- **Given** the chart recognizes Anthropic
- **When** a release candidate is assembled
- **Then** its immutable runtime image versions are recorded as supporting native
  Anthropic
- **And** a text and multimodal canary pass before production assignment
