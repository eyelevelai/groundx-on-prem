## MODIFIED Requirements

### Requirement: The `cognito` object is documented in `values.schema.json` and `sample.values.yaml`
The schema SHALL retain the supported `cognito` fields and reject unsupported fields. The minimal starter SHALL explain the `apiKeyOnly` default and link `docs/on-prem-identity.md` for local password login and Cognito configuration instead of embedding provider-specific settings or an unused administrator password.

#### Scenario: Minimal starter identifies authentication behavior
- **GIVEN** the starter values
- **WHEN** a customer reads its administrator configuration
- **THEN** it explains that the default uses API keys without password login
- **AND** it links the identity guide rather than including a `cognito` block or `admin.password`.
