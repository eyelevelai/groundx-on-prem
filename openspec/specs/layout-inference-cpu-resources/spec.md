# layout-inference-cpu-resources Specification

## Purpose
Defines how the Helm chart renders `layout-inference` container resources when CPU device mode is selected.

## Requirements
### Requirement: CPU layout inference omits GPU resources

When `layout.inference.deviceType` is `cpu`, the Helm chart SHALL render the `layout-inference` container without NVIDIA GPU extended resource keys in `resources.requests` or `resources.limits`.

#### Scenario: CPU mode uses default resources

- **GIVEN** the chart default `layout.inference.resources` includes `nvidia.com/gpu`
- **WHEN** the chart is rendered with `layout.inference.deviceType: cpu`
- **THEN** the `layout-inference` container resources do not include `nvidia.com/gpu` in requests or limits
- **AND** non-GPU resources such as CPU and memory remain rendered

#### Scenario: CPU mode overrides explicit GPU resources

- **GIVEN** a values file sets `layout.inference.deviceType: cpu`
- **AND** the same values file sets GPU keys under `layout.inference.resources.requests` or `layout.inference.resources.limits`
- **WHEN** the chart is rendered
- **THEN** the `layout-inference` container resources do not include GPU resource keys

#### Scenario: CPU mode overrides a zero GPU limit

- **GIVEN** a values file sets `layout.inference.deviceType: cpu`
- **AND** the same values file sets the `nvidia.com/gpu` key under `layout.inference.resources.limits` to `0`
- **WHEN** the chart is rendered
- **THEN** the `layout-inference` container resources do not include `nvidia.com/gpu` in requests or limits

#### Scenario: CPU mode overrides partial non-GPU resources

- **GIVEN** a values file sets `layout.inference.deviceType: cpu`
- **AND** the same values file overrides a non-GPU resource limit without setting a GPU key
- **WHEN** the chart is rendered
- **THEN** the `layout-inference` container resources do not include default GPU resource keys
- **AND** non-GPU resources remain rendered

### Requirement: Non-CPU layout inference keeps GPU resources

When `layout.inference.deviceType` is unset or not set to `cpu`, the Helm chart SHALL keep the existing `layout-inference` GPU resource rendering behavior.

#### Scenario: Default mode renders GPU resources

- **GIVEN** the chart defaults are used
- **WHEN** the chart is rendered
- **THEN** the `layout-inference` container resources include `nvidia.com/gpu: 1` in requests and limits

### Requirement: CPU layout inference preserves node placement

When `layout.inference.deviceType` is `cpu`, the Helm chart SHALL NOT change node placement fields based on the device type.

#### Scenario: CPU mode keeps explicit scheduling configuration

- **GIVEN** a values file sets `layout.inference.deviceType: cpu`
- **AND** the same values file sets node, affinity, toleration, or node selector settings
- **WHEN** the chart is rendered
- **THEN** the `layout-inference` Deployment keeps those scheduling settings
- **AND** the chart does not infer a different node group from `deviceType`

### Requirement: CPU is the only special resource mode

The Helm chart SHALL apply resource normalization only when `layout.inference.deviceType` is `cpu`.

All other `layout.inference.deviceType` values SHALL keep the existing resource rendering behavior.

#### Scenario: CPU mode is selected

- **GIVEN** a values file sets `layout.inference.deviceType: cpu`
- **WHEN** the chart is rendered
- **THEN** CPU resource normalization applies

#### Scenario: Other device type values keep existing behavior

- **GIVEN** a values file leaves `layout.inference.deviceType` unset or sets it to a value other than `cpu`
- **WHEN** the chart is rendered
- **THEN** GPU resource rendering is preserved
