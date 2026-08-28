# Extraction capture account configuration

## Requirement: Capture accounts are explicitly configured

The chart SHALL expose `integration.extractionCaptureAccounts` as an array of
unique, non-empty strings. Its default SHALL be empty.

### Scenario: No accounts are configured

- **GIVEN** the chart's default values
- **WHEN** the GroundX ConfigMap is rendered
- **THEN** `integrationTests.extractionCaptureAccounts` is omitted
- **AND** Cashbot's effective allowlist remains empty

### Scenario: Approved accounts are configured

- **GIVEN** one or more account IDs in `integration.extractionCaptureAccounts`
- **WHEN** the GroundX ConfigMap is rendered
- **THEN** `integrationTests.extractionCaptureAccounts` contains those exact IDs
- **AND** no other account is added

### Scenario: The value has an invalid shape

- **GIVEN** a non-array value, a non-string member, an empty member, or duplicate members
- **WHEN** Helm validates the values schema
- **THEN** validation fails before deployment

## Requirement: Capture authorization remains fail closed

This chart setting SHALL only supply Cashbot's existing server-side allowlist.
It SHALL NOT enable capture by itself or alter workflow capture validation,
expiry, limits, workflow binding, bucket binding, or extraction behavior.
