## ADDED Requirements

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
