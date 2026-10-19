## ADDED Requirements

### Requirement: CPU-only disk defaults preserve the lower-cost disk choice
The AWS Terraform SHALL default CPU-only root disks to gp3 with 3000 IOPS and 128 MiB/s. It SHALL preserve the default 30 GiB size, encryption, delete-on-termination behavior, and existing explicit operator disk overrides. Other node groups SHALL retain their previous disk defaults.

#### Scenario: Default CPU group
- **WHEN** an operator plans EKS with default node settings
- **THEN** the CPU-only launch template uses gp3, 3000 IOPS, and 128 MiB/s
- **AND** the other groups retain gp2 defaults

#### Scenario: Explicit disk settings
- **WHEN** the operator supplies CPU-only disk settings through the existing nodes input
- **THEN** the launch template uses those settings instead of the defaults

### Requirement: CPU updates limit simultaneous node unavailability
The CPU-only node group SHALL set maxUnavailable to 1 without also setting maxUnavailablePercentage. This setting SHALL NOT change other groups' update configuration.

#### Scenario: CPU node-group update
- **WHEN** EKS uses the generated CPU-only node-group configuration
- **THEN** its maximum unavailable node count is one

### Requirement: CloudWatch retains explicit cost controls
The CloudWatch add-on SHALL disable Application Signals auto-monitoring and automatic application restarts, omit Application Signals agent collection, and keep enhanced Container Insights for the configured cluster. These settings SHALL apply whether DNS collection is enabled or disabled.

#### Scenario: DNS collection disabled
- **WHEN** DNS collection is disabled
- **THEN** the add-on has one explicitly configured main agent and the cost controls remain active

#### Scenario: DNS collection enabled
- **WHEN** DNS collection is enabled
- **THEN** the same main-agent and manager cost settings remain active alongside exactly one CoreDNS deployment collector
