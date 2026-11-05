## ADDED Requirements

### Requirement: README preserves the established editorial baseline
The main README SHALL reuse the language and structure of `aecde7bc63029f936f85051de023c0aa10a9a798:README.md` wherever accurate, while updating changed deployment facts and keeping its customer-facing product introduction and installation purpose.

#### Scenario: Reader follows the main installation path
- **GIVEN** a human evaluating or installing the current release
- **WHEN** they read the README
- **THEN** the baseline's product explanation, requirements, ordered installation and first-use structure remain recognizable
- **AND** required settings, commands and security prerequisites reflect current source rather than the historical release.

### Requirement: Useful current information remains available
The documentation SHALL preserve useful current instructions, configuration examples, limitations, migration ordering and rollback steps, placing detail in existing appropriate guides before creating new files. Established links SHALL be updated or retain a short pointer at their old heading.

#### Scenario: Detailed upgrade procedure moves
- **GIVEN** an existing customer following a README upgrade link
- **WHEN** the full procedure is relocated
- **THEN** a visible warning and working link lead to the complete procedure
- **AND** its compatibility requirements, credential handling, data protections and rollback instructions remain available.

### Requirement: Humans and agents use shared technical guidance
The documentation SHALL give humans a clear README and topic guides, and agents short indexes plus repository/skill working guidance that refers to the same technical sources. Optional features SHALL NOT require new main-README sections, and `AGENTS.md` SHALL remain a table of contents.

#### Scenario: Optional feature has detailed configuration
- **GIVEN** optional Workspace or diagnostic information
- **WHEN** the documentation is organized
- **THEN** a relevant guide preserves its usable details
- **AND** the README links it in proportion to its relevance to first use.

### Requirement: Cross-repository maintenance uses written guidance
The on-prem repository guide and Harness on-prem maintenance guidance SHALL tell contributors to check and update affected counterpart references when facts or paths change. This change SHALL use existing validation and packaging, without new synchronization automation, mandatory companion-PR gates or additional prose-placement scanners.

#### Scenario: Install instructions move without behavior changes
- **GIVEN** installation instructions move to an existing or justified topic guide
- **WHEN** a contributor follows the maintenance guidance
- **THEN** they check counterpart links and references, adjust those affected and retain any unchanged guidance
- **AND** any existing command check still verifies the same behavior against the new owner.
