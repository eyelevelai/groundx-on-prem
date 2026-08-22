## ADDED Requirements

### Requirement: Diagnostic rollout preserves external KMS policy

The AWS EKS Terraform SHALL pass explicitly configured KMS source policy
documents unchanged to the EKS module, and SHALL default to no additional
documents.

#### Scenario: No external policy is configured

- **GIVEN** the KMS source policy input is omitted
- **WHEN** Terraform plans the EKS stack
- **THEN** it passes an empty source-policy list to the EKS module
- **AND** existing environments retain their prior default behavior.

#### Scenario: Production policy is configured

- **GIVEN** the current production Inspector statement is configured as a KMS
  source policy document
- **WHEN** Terraform plans the targeted node monitoring add-on
- **THEN** the statement remains in the planned KMS policy
- **AND** the plan creates only the node monitoring add-on
- **AND** it contains no update, replacement, or deletion.
