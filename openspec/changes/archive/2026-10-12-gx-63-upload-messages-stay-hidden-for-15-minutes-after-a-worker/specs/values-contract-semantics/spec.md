## ADDED Requirements

### Requirement: AWS example values state the upload queue hold
The AWS services example values SHALL state, in the comment above the `stream.topics` block, that the 10+ minute visibility timeout applies to every SQS queue except upload, and that upload holds in-flight messages for 5 minutes. The comment SHALL NOT change any key, value, default, or rendered manifest. The statement SHALL be identical in `src/groundx/values/values.aws.services.yaml` and its published mirror `helm/values/values.aws.services.yaml`.

#### Scenario: Both surfaces carry the upload exception
- **WHEN** an operator reads `values.aws.services.yaml` in `src/groundx` or in `helm`
- **THEN** the comment says upload holds in-flight messages for 5 minutes
- **AND** it still says the other SQS queues need a 10+ minute visibility timeout

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
