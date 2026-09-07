# Anthropic workflow engine service

## ADDED Requirements

### Requirement: Explicit model services are rendered without provider policy

The chart MUST preserve any explicitly configured model service and its supplied
settings without using a provider-name allowlist.

#### Scenario: Summary selects Anthropic

- **Given** summary existing-service or per-engine values select `anthropic`
- **When** the chart renders application configuration
- **Then** the exact service, supplied summary URL or engine base URL, and engine ID
  are rendered
- **And** the supplied URL is an API root rather than the Messages operation endpoint
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
- **And** the supplied endpoint is an API root rather than the Messages operation
  endpoint
- **And** no in-cluster endpoint, model, kwargs, or reasoning default is substituted

#### Scenario: Custom extraction service is selected

- **Given** `extract.agent.serviceType` contains a custom service value
- **When** the chart renders extraction-agent configuration
- **Then** that exact service value is rendered
- **And** no in-cluster key, endpoint, model, kwargs, or reasoning default is
  substituted

#### Scenario: Service is omitted

- **Given** no summary or extraction service is explicitly configured
- **When** the chart renders application configuration
- **Then** the existing in-cluster EyeLevel defaults remain unchanged
- **And** local summary workloads are deployed for both consumers

#### Scenario: Summary and extraction select different services

- **Given** a summary engine explicitly selects one service
- **And** the extraction agent explicitly selects a different service
- **When** the chart renders application configuration
- **Then** each consumer receives only its own configured model settings
- **And** neither consumer inherits the other consumer's service, key, URL, model, or
  options

#### Scenario: External summary and default extraction coexist

- **Given** all summary engines explicitly select external services
- **And** extraction is enabled without an explicit extraction service
- **When** the chart renders workloads and application configuration
- **Then** extraction receives the existing local EyeLevel defaults
- **And** the local summary API and inference workloads remain deployed for extraction

### Requirement: Model settings resolve once

The chart MUST use one presence-aware model-resolution contract for summary and
extraction, with separate adapters for their existing output formats. Workload creation,
validation, and rendered configuration MUST consume the same resolved result.

#### Scenario: Engine ID is set without a service

- **Given** a named summary engine has an engine ID but no `service` or `serviceType`
- **And** `summary.existing` is not configured
- **When** the chart renders
- **Then** the engine receives the chart-managed EyeLevel service, key, and URL
- **And** the local summary workloads remain deployed

#### Scenario: Explicit empty value is preserved

- **Given** a model key, URL, model, option, or reasoning property is explicitly set to
  an empty value
- **When** model settings resolve
- **Then** that property remains empty
- **And** no local or global default replaces it

#### Scenario: Empty service retains legacy omission behavior

- **Given** `service` or `serviceType` is empty
- **When** model settings resolve
- **Then** service selection treats that value as omitted

#### Scenario: EyeLevel-compatible external endpoint is supplied

- **Given** a model resolves to `eyelevel`
- **And** its URL was explicitly supplied or inherited
- **When** the chart renders
- **Then** that URL is preserved
- **And** that model does not require chart-managed summary workloads

#### Scenario: Mixed local and external engines

- **Given** one summary engine resolves to the chart-managed EyeLevel service
- **And** another engine explicitly selects an external service
- **When** the chart renders
- **Then** local credentials and endpoints are assigned only to the local engine
- **And** local summary workloads remain deployed

### Requirement: Explicit credentials pass through without chart policy

The chart MUST render any explicitly supplied provider credential regardless of service
name and MUST NOT require or invent one for an explicitly configured service.

#### Scenario: Existing credential sources work

- **Given** Anthropic is selected with a supported summary or extraction credential
  source
- **When** the chart renders
- **Then** it passes that source through the existing credential contract
- **And** it does not substitute the GroundX admin API key

#### Scenario: Credential is missing

- **Given** any service is explicitly selected without a provider credential
- **When** the chart renders
- **Then** rendering succeeds without a provider key
- **And** the GroundX admin API key is not substituted

#### Scenario: Cashbot loads a keyless external engine

- **Given** the rendered configuration contains a keyless engine with an explicit
  external service
- **And** a global or local GroundX key exists
- **When** Cashbot loads and initializes the engine
- **Then** the external engine remains keyless
- **And** the GroundX key is not sent to that provider

### Requirement: Existing defaults remain stable

The chart MUST retain current local behavior when no service is explicitly configured.
Explicit services use the provider-neutral pass-through behavior and documented
per-engine `service` takes precedence over legacy `serviceType`.

#### Scenario: Documented per-engine service wins

- **Given** a custom non-default engine supplies conflicting `service` and
  `serviceType` values
- **When** the chart renders application configuration
- **Then** the documented `service` value is rendered
- **And** the chart release notes identify the upgrade behavior change.

#### Scenario: Omitted-service regression suite

- **Given** the existing fixtures that omit a model service
- **When** the full Helm validation gate runs
- **Then** their local routing and credential defaults remain unchanged

### Requirement: Chart and runtime support are released together

The chart MUST NOT advertise or release Anthropic configuration with an application
image that lacks the matching native provider adapter.

#### Scenario: Release is prepared

- **Given** the chart recognizes Anthropic
- **When** a release candidate is assembled
- **Then** its immutable runtime image versions are recorded as supporting native
  Anthropic
- **And** a text and multimodal canary pass before production assignment
