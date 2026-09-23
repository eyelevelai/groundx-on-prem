## ADDED Requirements

### Requirement: Chart renders the operator's selected identity mode
The chart SHALL render a `cognito: { mode: <value> }` block into the deployed `config.yaml`
ConfigMap whenever the operator sets `cognito.mode` in values, for every accepted value —
`apiKeyOnly`, `cognito`, or the new `local` — without changing how any other value renders.

#### Scenario: operator selects local mode — finalize success
- **GIVEN** an install that sets `cognito.mode: local`
- **WHEN** the chart renders `config-yaml.yaml`
- **THEN** the deployed `config.yaml` contains a `cognito:` block whose `mode` is `local`

#### Scenario: an existing enum value keeps rendering unchanged — finalize success
- **GIVEN** an install that sets `cognito.mode: cognito` (an existing, pre-change value)
- **WHEN** the chart renders `config-yaml.yaml`
- **THEN** the deployed `config.yaml` contains a `cognito:` block whose `mode` is `cognito`,
  identical in shape to the `local` case

### Requirement: An install that never sets the value is unaffected
The chart SHALL render no `cognito` key at all when the operator does not set `cognito.mode`, so
an install that predates this change, or simply never opts in, is byte-for-byte unaffected.

#### Scenario: unset install renders no cognito block — backward-compatible, no render
- **GIVEN** an install that does not set `cognito.mode` (today's only supported state)
- **WHEN** the chart renders `config-yaml.yaml`
- **THEN** the deployed `config.yaml` contains no `cognito` key at all

#### Scenario: chart-side rollout is independent of the producer's rollout order — backward compatibility
- **GIVEN** this chart change and cashbot-go's `local`-mode support deploy in either order (both
  additive, per the cross-service contract)
- **WHEN** an operator upgrades the chart alone, without setting `cognito.mode`
- **THEN** the rendered `config.yaml` is identical to the pre-change chart's output, regardless of
  which cashbot-go image version is deployed alongside it

### Requirement: The values contract accepts the new key on both chart surfaces
`values.schema.json` SHALL accept a `cognito.mode` string key on both the `src/groundx` and the
published `helm` chart surfaces, consistent with the schema's existing `additionalProperties:
false` strictness at the root.

#### Scenario: schema accepts the new key — finalize success
- **GIVEN** `values.schema.json` on either chart surface
- **WHEN** an install sets `cognito.mode` to any string value
- **THEN** schema validation accepts the values file (no "additional properties 'cognito' not
  allowed" rejection)

### Requirement: The src and published chart surfaces stay byte-identical
Every file this change touches SHALL be byte-identical between `src/groundx/` (the source of
truth) and `helm/` (the published mirror), matching the chart's existing manual-mirror convention.

#### Scenario: touched files match across chart surfaces — finalize success
- **GIVEN** the values-schema, template, and helper files this change touches
- **WHEN** the same file is compared between `src/groundx/` and `helm/`
- **THEN** the two copies are byte-for-byte identical

### Requirement: Operator/customer documentation describes the local-mode flow
The chart's README SHALL document the `cognito.mode` values key (including `local`), the
password-login flow it enables (register, bcrypt-verified login returning the customer body with
no token, admin-mediated password reset with no email/SES), that customers keep using API keys for
GroundX API access unchanged under every mode, and that `admin.password` stays unused for admin
login under every mode.

#### Scenario: README documents the new mode and the caveat
- **GIVEN** `src/groundx/README.md`
- **WHEN** an operator reads the values table and the identity-mode section
- **THEN** it lists `cognito.mode` (including `local`) among the configurable parameters, describes
  the local password-login and admin-mediated-reset flow, and flags that `admin.password` is not an
  admin-login credential under `local` or any other mode
