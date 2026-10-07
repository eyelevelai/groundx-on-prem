# Deployment configuration

## ADDED Requirements

### Requirement: Extraction capture domains are configurable

The chart SHALL expose `integration.extractionCaptureDomains` as an array of unique, non-empty strings and render configured values under `integrationTests.extractionCaptureDomains` in the shared `config.yaml`.
Its default SHALL be empty and the runtime key SHALL be omitted when no domains are configured.

#### Scenario: No domains are configured

- **GIVEN** the chart's default values
- **WHEN** the GroundX config is rendered
- **THEN** `integrationTests.extractionCaptureDomains` is omitted

#### Scenario: Internal domains are configured

- **GIVEN** an operator configures `eyelevel.ai` and `valantor.com`
- **WHEN** the chart renders the GroundX config
- **THEN** the same two domain strings appear under `integrationTests.extractionCaptureDomains`
- **AND** the existing account-ID list remains unchanged

#### Scenario: Invalid domains value

- **GIVEN** a non-array, empty member, non-string member, or duplicate member
- **WHEN** Helm validates values
- **THEN** validation fails before deployment

### Requirement: Chart configuration does not bypass capture authorization

Rendering domains SHALL NOT enable capture without a valid workflow marker or change Cashbot's bucket, expiry, artifact, and workflow binding checks. The chart SHALL NOT claim to configure the separately deployed hosted Lambda.

#### Scenario: Domain list is configured without a capture marker

- **GIVEN** the chart renders an internal domain
- **WHEN** an extraction workflow has no enabled capture marker
- **THEN** the runtime does not create private capture artifacts
- **AND** the hosted Lambda remains governed by its separate Cashbot configuration
