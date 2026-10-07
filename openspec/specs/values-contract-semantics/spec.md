# values-contract-semantics Specification

## Purpose
Define how schema-valid compatibility fields are represented, tested, and kept consistent across the source and published chart surfaces.
## Requirements
### Requirement: Accepted values distinguish compatibility from behavior
The chart SHALL keep `cluster.hasMig` and `cluster.tls.existingSecret` schema-valid for 0.2.7 compatibility, SHALL mark both fields deprecated, and SHALL state that neither field changes rendered resources.

#### Scenario: Existing values retain schema compatibility
- **WHEN** Helm validates values containing either deprecated field
- **THEN** schema validation succeeds
- **AND** the schema identifies the field as deprecated and inert

#### Scenario: Deprecated fields do not change manifests
- **WHEN** the chart is rendered once with default values and once with either deprecated field set
- **THEN** the Kubernetes manifests are identical

### Requirement: Operator output does not claim unsupported TLS behavior
The chart SHALL NOT report that a TLS Secret is configured unless a supported template consumes that Secret.

#### Scenario: Helm notes render for the current chart
- **WHEN** the chart notes are evaluated
- **THEN** they do not read the nonexistent top-level `tls.existingSecret` path
- **AND** they do not claim that `cluster.tls.existingSecret` is mounted or used

### Requirement: Published and source chart surfaces agree
The `src/groundx` source chart and `helm` publication mirror SHALL expose the same deprecation metadata and template behavior for these fields.

#### Scenario: Both chart surfaces are validated
- **WHEN** the production Helm gate runs
- **THEN** it validates schema metadata and render equivalence for both chart surfaces
