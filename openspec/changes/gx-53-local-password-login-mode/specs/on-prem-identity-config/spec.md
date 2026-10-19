## ADDED Requirements

### Requirement: `cognito.mode` accepts `local` as a valid password-login identity value

`values.schema.json` (and its mirror `helm/values.schema.json`) SHALL accept `local` as a valid
enum value for `cognito.mode`, alongside the existing `cognito` and `apiKeyOnly` values.
`templates/resources/config-yaml.yaml`'s existing verbatim render of `cognito.mode` (via the
`groundx.cognito.mode` helper) SHALL render `local` exactly as it renders any other accepted
value — no new template, helper, or guard logic is required or introduced by this change.

#### Scenario: `cognito.mode: local` renders `mode: "local"` (polarity: finalize success)

- **GIVEN** a `values.yaml` that sets `cognito.mode: local`
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`, in either
  `src/groundx/` or `helm/`
- **THEN** the rendered `config.yaml` contains a `cognito:` block whose `mode` field is the
  quoted string `"local"`

#### Scenario: An unrecognized `cognito.mode` value stays rejected (polarity: reject before state)

- **GIVEN** a `values.yaml` that sets `cognito.mode` to a value other than `cognito`,
  `apiKeyOnly`, or `local`
- **WHEN** `helm template`/`helm lint` validates the values against `values.schema.json`, on
  either chart surface
- **THEN** validation fails and no `config.yaml` is rendered — the opposite outcome (silently
  accepting the value, or falling through to a default) must not occur

#### Scenario: The enum widening does not change either existing value's render (polarity: finalize success)

- **GIVEN** a `values.yaml` that sets `cognito.mode: cognito` or `cognito.mode: apiKeyOnly`
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`
- **THEN** the rendered `cognito:` block is byte-for-byte unchanged from before this change

#### Scenario: An install upgraded without opting in keeps working unchanged (backward compatibility — cross-service touchpoint)

- **GIVEN** an on-prem install's `values.yaml` predates this change, or sets `cognito.mode` to
  `cognito`/`apiKeyOnly`, or omits `cognito.mode` entirely
- **WHEN** the chart is upgraded to the version carrying this change, with or without a
  cashbot-go image that supports `local`
- **THEN** the rendered `config.yaml` is unchanged for that install, and cashbot-go's own runtime
  behavior for `apiKeyOnly`/`cognito` is unaffected — no chart-side action is required to keep
  working exactly as it did before the upgrade

#### Scenario: The schema change stays mirrored between chart surfaces (polarity: finalize success)

- **GIVEN** this change is fully applied
- **WHEN** `diff -q` compares `src/groundx/values.schema.json` to `helm/values.schema.json`
- **THEN** the comparison reports no difference
