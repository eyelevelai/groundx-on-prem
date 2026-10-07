# account-file-size-routing Specification

## Purpose
Define account-owned PDF byte limits and executable-relative helper discovery in the large-file delivery chart configuration.

## Requirements

### Requirement: Account file size owns the byte limit
The chart SHALL render enabled routing configuration without maxPDFBytes or helperPath and SHALL require compatible producer images that use account maxFileSize and locate the page-count helper beside their executable. Time budgets, credentials and transports SHALL retain their existing configuration.

#### Scenario: Enabled delivery uses account size
- **WHEN** the existing large-file delivery configuration is rendered without counting.maxPDFBytes
- **THEN** Kafka and SQS configurations render successfully without a deployment byte limit

#### Scenario: Disabled delivery remains unchanged
- **WHEN** large-file delivery is disabled
- **THEN** existing manifests and configuration hashes remain unchanged

#### Scenario: Obsolete override is supplied
- **WHEN** counting.maxPDFBytes or counting.helperPath appears in operator values
- **THEN** schema validation rejects the obsolete setting
