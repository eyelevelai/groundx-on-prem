# new-install-values Specification

## Purpose

Define the minimal customer starter, operator verification before file-access activation, preservation of customized values on upgrades and concise documentation entrypoints.

## Requirements
### Requirement: Minimal starter values retain required installation choices
The starter SHALL use supported keys and show license/admin identity, Kubernetes storage selection, database/search credentials and protected-file storage/delivery configuration. It SHALL use replacement credential placeholders and link optional identity configurations rather than embedding them.

#### Scenario: Completed starter renders protected file configuration
- **GIVEN** a customer copies the starter and supplies its own credentials, license and endpoints
- **AND** private storage and encrypted transport have been independently verified
- **WHEN** the source or published chart renders with both assertions true
- **THEN** configuration contains the supplied license and enabled file gateway with distinct native storage/signing endpoints
- **AND** the packaged chart default remains disabled.

### Requirement: Starter verification assertions require operator action
The starter SHALL enable file access while leaving private-origin and encrypted-transport verification assertions false until verified by the operator.

#### Scenario: Unverified installation is rejected
- **GIVEN** the starter with either verification assertion false
- **WHEN** the chart renders
- **THEN** it fails with the existing named verification requirement rather than deploying unverified protection.

### Requirement: Upgrades retain customer-owned values
The install guide SHALL instruct customers to retain and pass their customized values file on upgrades and SHALL prohibit replacing an existing installation's values with the new-install sample as an upgrade procedure.

#### Scenario: Existing installation upgrades
- **GIVEN** an existing customer-owned values file
- **WHEN** the customer follows the upgrade instructions
- **THEN** the Helm command uses that file and does not copy the new-install sample over it.

### Requirement: Repository agent entrypoint remains a table of contents
`AGENTS.md` SHALL remain a short table of contents linking to repository guidance, contribution instructions and relevant operator guides. Detailed rules, including the purpose and inclusion criteria for `sample.values.yaml`, SHALL live in the linked repository guide. Relocation SHALL preserve existing operational and safety instructions and update references to their new location.

#### Scenario: Agent reads customer starter rules
- **GIVEN** an agent starts at `AGENTS.md`
- **WHEN** it follows the customer starter link
- **THEN** the repository guide explains the minimal new-install sample and excludes optional provider blocks such as Cognito
- **AND** `AGENTS.md` contains links rather than embedded procedures.

### Requirement: Customer documentation prioritizes evaluation and first installation
Repository guidance SHALL define the main README as a concise customer-facing product introduction and quick start. It SHALL place optional features and detailed operating procedures in linked guides, keep critical warnings beside affected steps, preserve useful instructions when relocating them and require plain English without internal engineering context.

#### Scenario: Optional feature documentation is added
- **GIVEN** a feature that is not required to evaluate, install or begin using GroundX
- **WHEN** its documentation is added
- **THEN** detailed configuration belongs in the relevant guide
- **AND** the main README receives a link only where it helps the reader.
