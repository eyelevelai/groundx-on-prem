# Extract Terminal Agent Trace Config Specification

## Purpose

Define how the chart exposes terminal agent tracing to all extract pods through
a shared default and pod-specific overrides.

## ADDED Requirements

### Requirement: Shared extract setting

The chart SHALL expose `extract.terminalAgentTraceEnabled` as a boolean with a
default value of `false`.

#### Scenario: Shared setting is omitted

- **GIVEN** the operator omits `extract.terminalAgentTraceEnabled`
- **WHEN** the chart renders the extract deployments
- **THEN** every extract pod receives
  `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED="false"`.

#### Scenario: Shared setting is enabled

- **GIVEN** `extract.terminalAgentTraceEnabled` is `true`
- **WHEN** the chart renders the extract deployments
- **THEN** every extract pod receives
  `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED="true"` unless that pod has an
  explicit override.

### Requirement: Pod setting takes precedence

The chart SHALL accept optional `terminalAgentTraceEnabled` boolean overrides
under `extract.api`, `extract.agent`, `extract.download`, and `extract.save`.

#### Scenario: Pod disables shared enabled setting

- **GIVEN** `extract.terminalAgentTraceEnabled` is `true`
- **AND** `extract.api.terminalAgentTraceEnabled` is `false`
- **WHEN** the chart renders the extract deployments
- **THEN** the API pod receives
  `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED="false"`
- **AND** the other extract pods receive
  `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED="true"`.

#### Scenario: Pod enables shared disabled setting

- **GIVEN** `extract.terminalAgentTraceEnabled` is `false`
- **AND** `extract.agent.terminalAgentTraceEnabled` is `true`
- **WHEN** the chart renders the extract deployments
- **THEN** the agent pod receives
  `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED="true"`
- **AND** the other extract pods receive
  `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED="false"`.

### Requirement: Strict schema validation

The chart SHALL accept only boolean values for the shared and pod settings.

#### Scenario: Operator uses a string value

- **GIVEN** any terminal trace setting is the string `"true"`
- **WHEN** Helm validates the values
- **THEN** schema validation fails.

### Requirement: Existing deployment topology is preserved

The chart SHALL expose the setting without adding Kubernetes resources or
changing stateful configuration.

#### Scenario: Terminal trace is enabled

- **WHEN** the chart renders with terminal trace enabled
- **THEN** only the environment of existing extract deployments changes
- **AND** no service, queue, PVC, RBAC resource, HPA, or stateful resource is
  added or changed.

### Requirement: Runtime rollout remains externally gated

The chart SHALL NOT treat environment rendering as proof that terminal
diagnostics are safe or active.

#### Scenario: Chart implementation is complete

- **WHEN** chart tests prove the shared and pod values render correctly
- **THEN** no production capture is enabled by this chart change
- **AND** deployment remains gated by the Internal Arcadia AGE-272 storage,
  budget, security, readiness, and natural-failure checks
- **AND** those runtime checks prove API failure diagnostics use one best-effort
  one-second transport budget while preserving status and body, without
  claiming a hard wall-clock limit
- **AND** Celery callback retry or requeue retains no terminal artifact or
  processing terminal record.
