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

### Requirement: AWS example values state the upload queue hold
The AWS services example values SHALL state, in the comment above the `stream.topics` block, that the 10+ minute visibility timeout applies to every SQS queue, that the upload, process and summary consumers re-hide their in-flight messages for 5 minutes renewed every minute, and that a DLQ on the upload queue needs a maxReceiveCount of 4 or more. The comment SHALL NOT change any key, value, default, or rendered manifest. The statement SHALL be identical in `src/groundx/values/values.aws.services.yaml` and its published mirror `helm/values/values.aws.services.yaml`.

#### Scenario: Both surfaces carry the upload exception
- **WHEN** an operator reads `values.aws.services.yaml` in `src/groundx` or in `helm`
- **THEN** the comment says the upload, process and summary consumers re-hide their in-flight messages for 5 minutes, renewed every minute
- **AND** it says a DLQ on the upload queue needs a maxReceiveCount of 4 or more
- **AND** it still says SQS queues need a 10+ minute visibility timeout

#### Scenario: Other queues keep the 10+ minute requirement
- **WHEN** an operator sizes the `preProcess`, `process`, `summary`, or `update` SQS queues from the comment
- **THEN** the comment still requires 10+ minutes for them
- **AND** the comment does not tell the operator to shorten their timeout

#### Scenario: Comment edit does not change rendered output
- **WHEN** the chart is rendered with the edited values file and again with the same file with comment lines removed
- **THEN** the Kubernetes manifests are identical
- **AND** no key or value under `stream.topics` differs from before the edit

#### Scenario: Existing installations are unaffected during rollout
- **WHEN** an existing installation, including one on Kafka that never reads an SQS lease, upgrades to the edited chart files
- **THEN** its rendered resources, config hashes, and pod specs are unchanged
- **AND** no workload restarts because of this edit

