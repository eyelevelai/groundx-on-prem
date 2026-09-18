## ADDED Requirements

### Requirement: The `cognito` block renders in cashbot-go's `config.yaml` Secret when a Cognito key is set

`templates/resources/config-yaml.yaml` (and its manual mirror `helm/templates/resources/config-yaml.yaml`) SHALL render a `cognito:` block inside the rendered `config.yaml` document whenever at least one of `cognito.mode`, `cognito.clientId`, `cognito.clientSecret`, `cognito.poolId`, `cognito.region` is a non-empty value, guarded exactly as the existing `admin:` block is guarded (a block-level `{{- if or (...) }}` plus one independent `{{- if ne (...) "" }}` per key), using new `groundx.cognito.mode`/`groundx.cognito.clientId`/`groundx.cognito.clientSecret`/`groundx.cognito.poolId`/`groundx.cognito.region` helpers added to `templates/_helpers/main.tpl` beside the existing `groundx.admin.*` helpers.

#### Scenario: A complete Cognito config renders all five keys (polarity: finalize success)

- **GIVEN** `cognito.mode=cognito`, `cognito.clientId`, `cognito.clientSecret`, `cognito.poolId`, and `cognito.region` are all set to non-empty values
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`
- **THEN** the rendered `stringData["config.yaml"]` contains a `cognito:` block with `mode`, `clientId`, `clientSecret`, `poolId`, and `region` fields equal to the configured values, at the same nesting depth as the existing `admin:` block
- **AND THEN** every other currently-rendered top-level key (`admin`, `ai`, `owner`, …) is unaffected

#### Scenario: A partially-set Cognito config renders only the keys that are set (polarity: finalize success)

- **GIVEN** only `cognito.mode=cognito` is set and `clientId`/`clientSecret`/`poolId`/`region` are unset
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`
- **THEN** the rendered `cognito:` block contains only `mode: cognito` — no empty `clientId: ""`/`poolId: ""`/etc. lines are emitted (the chart never fabricates a value for a key it was not given; cashbot-go's own `Cognito.Validate()` is what fails startup on an incomplete `mode: cognito` config, not the chart)

### Requirement: No `cognito` key renders when no Cognito value is set, and every unrelated existing install stays byte-identical on upgrade

`templates/resources/config-yaml.yaml` SHALL emit no `cognito:` key at all when `cognito.mode`, `cognito.clientId`, `cognito.clientSecret`, `cognito.poolId`, and `cognito.region` are all unset — the 0.2.7 default and every existing on-prem install's current `values.yaml` — so an install upgrading to this chart version without adding any `cognito.*` key renders a `config.yaml` unchanged from before this proposal, and cashbot-go's own `apiKeyOnly` default governs its runtime behavior exactly as it does today.

#### Scenario: No Cognito value set renders no `cognito` key at all (polarity: reject before state — no new key, no new state)

- **GIVEN** a `values.yaml` that does not set any `cognito.*` key (including the chart's own default `values.yaml` and every existing customer `values.yaml` prior to this change)
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`, in either `src/groundx/` or `helm/`
- **THEN** the rendered `config.yaml` contains zero occurrences of the string `cognito`, and every other rendered key is unchanged from the chart's pre-GX-20 output — the opposite outcome (a stray `cognito:` key, an empty `cognito: {}`, or any other new content) must not occur

#### Scenario: An on-prem install upgraded without new values keeps working exactly as before (backward compatibility — cross-service touchpoint)

- **GIVEN** a running on-prem install's `values.yaml` predates this change and sets no `cognito.*` key
- **WHEN** the chart is upgraded to the version carrying this change and `helm template`/`helm upgrade` re-renders `config-yaml-map`
- **THEN** the rendered `config.yaml` is unchanged for that install, cashbot-go's `server/*` binaries load it and default to `mode: apiKeyOnly` (cashbot-go's own safe default — confirmed by the FINALIZED contract), and the seeded admin + API-key path continues to work exactly as it did before the upgrade — no chart-side action is required for an install that does not want Cognito

### Requirement: `cognito.adminPassword` cannot be expressed through the chart under any configuration

The `cognito` object added to `values.schema.json` (and its mirror `helm/values.schema.json`) SHALL declare exactly `mode`, `clientId`, `clientSecret`, `poolId`, `region` with `additionalProperties: false`, so a `values.yaml` that sets `cognito.adminPassword` is rejected by schema validation rather than silently accepted, ignored, or rendered — `cognito.adminPassword` is Cloud-load-bearing only (per the FINALIZED contract) and `server/GroundX` on-prem keeps `FullConfig=nil` so that field must never reach the on-prem render.

#### Scenario: `cognito.adminPassword` in values.yaml fails schema validation, not silent rendering (polarity: skip unrelated repair path)

- **GIVEN** a `values.yaml` that sets `cognito.mode: cognito` and additionally `cognito.adminPassword: <any value>`
- **WHEN** `helm template` (or `helm lint`) renders the chart, in either `src/groundx/` or `helm/`
- **THEN** the command fails with a schema validation error naming `adminPassword` as a disallowed property of `cognito` — it does **not** render successfully with `adminPassword` silently dropped, and it does **not** render `adminPassword` into the output

### Requirement: The Cognito client secret is delivered through the existing Secret-kind `config.yaml` render, never a new resource

`cognito.clientSecret` SHALL render inside `templates/resources/config-yaml.yaml`'s existing `stringData` block — the same resource that has rendered as `kind: Secret` since GX-17 — and this change SHALL NOT add a second Secret (or ConfigMap) resource to carry any Cognito key.

#### Scenario: The rendered resource carrying `clientSecret` is `kind: Secret` (polarity: finalize success)

- **GIVEN** `cognito.clientSecret` is set to a non-empty value
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`
- **THEN** the single rendered document has `kind: Secret` and its `stringData["config.yaml"]` contains the `clientSecret` field — no second document, and no `kind: ConfigMap`, is rendered for this template

### Requirement: `src/groundx/` and `helm/` render identically for every file this change touches

Every change to `templates/_helpers/main.tpl`, `templates/resources/config-yaml.yaml`, and `values.schema.json` under `src/groundx/` SHALL be mirrored byte-for-byte into `helm/templates/_helpers/main.tpl`, `helm/templates/resources/config-yaml.yaml`, and `helm/values.schema.json` respectively (the manual mirror this repo maintains with no regen guard).

#### Scenario: The three touched files are byte-identical between `src/groundx/` and `helm/` (polarity: finalize success)

- **GIVEN** this change is fully applied
- **WHEN** `diff -q` compares `src/groundx/templates/_helpers/main.tpl` to `helm/templates/_helpers/main.tpl`, `src/groundx/templates/resources/config-yaml.yaml` to `helm/templates/resources/config-yaml.yaml`, and `src/groundx/values.schema.json` to `helm/values.schema.json`
- **THEN** all three comparisons report no difference

### Requirement: The `cognito` object is documented in `values.schema.json` and `sample.values.yaml`

`values.schema.json` SHALL declare a `cognito` object (`mode`, `clientId`, `clientSecret`, `poolId`, `region`, all `type: string`, `additionalProperties: false`) matching the existing `admin` block's shape, and `sample.values.yaml` SHALL document all five keys with a comment noting the `apiKeyOnly` default (no chart change required to stay on it) — without removing or otherwise touching the existing `admin.password` key, which GX-20 leaves as-is by assignee decision.

#### Scenario: `sample.values.yaml` documents every `cognito` key and the `apiKeyOnly` default (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** `sample.values.yaml` is inspected
- **THEN** it contains a `cognito:` section documenting `mode`, `clientId`, `clientSecret`, `poolId`, and `region`, a comment stating that omitting this section keeps the install on `apiKeyOnly`, and the pre-existing `admin:` block (including `admin.password`) is present and unchanged

### Requirement: The on-prem identity story is documented in `docs/`

`docs/` SHALL contain a document stating the default `apiKeyOnly` identity behavior, the optional `cognito` mode and its required keys, and the explicit air-gapped answer (`apiKeyOnly` — `mode: cognito` requires reaching AWS Cognito, which an air-gapped cluster cannot do).

#### Scenario: The identity-story doc covers both modes and the air-gapped answer (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** the new `docs/` file is inspected
- **THEN** it states the `apiKeyOnly` default, documents the `cognito.*` keys required to opt into `mode: cognito`, and explicitly states that air-gapped installs must stay on `apiKeyOnly`

## Amendments

### 2026-09-16 — review-fix round 1

#### Requirement (amended): `cognito.mode` is enum-constrained by the chart schema

`values.schema.json` (and its mirror `helm/values.schema.json`) SHALL declare `cognito.mode` as
`enum: ["cognito", "apiKeyOnly"]`, so any other value fails schema validation at `helm
template`/`helm lint` time rather than rendering and then silently falling back to `apiKeyOnly`
at cashbot-go startup. This supersedes this document's original "`cognito.mode` is `type:
string`, no enum" position (see `design.md` Amendments for the rationale). `cognito` remains
fully optional; the enum constrains the value only when the key is present.

##### Scenario: An unrecognized `cognito.mode` value fails schema validation (polarity: reject before state)

- **GIVEN** a `values.yaml` that sets `cognito.mode` to a value that is neither `cognito` nor `apiKeyOnly`
- **WHEN** `helm template`/`helm lint` is run against `src/groundx` or `helm`
- **THEN** the command fails with a schema validation error naming `cognito.mode` as the offending property — it does **not** render, and it does **not** silently fall back to any mode

##### Scenario: The two known `cognito.mode` values still render (polarity: must not block)

- **GIVEN** a `values.yaml` that sets `cognito.mode` to `cognito` or to `apiKeyOnly`
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml` in either `src/groundx/` or `helm/`
- **THEN** the command succeeds and renders the configured `mode` value unchanged

#### Requirement (amended): `sample.values.yaml` ships no active `cognito` block by default

The `cognito:` example documented in `sample.values.yaml` SHALL be commented out in its entirety
(all five keys shown, each prefixed `#`, plus a note stating "Uncomment and fill to enable
Cognito login; omit to stay on the apiKeyOnly identity default") — supersedes this document's
original wording, which described an *active* `cognito:` block with placeholder values as the
default. The `admin:` block, including `admin.password`, is unchanged.

##### Scenario: A default copy of `sample.values.yaml` renders no active `cognito` block (polarity: reject before state)

- **GIVEN** an unmodified copy of `sample.values.yaml`
- **WHEN** it is rendered with `helm template` (schema-unrelated top-level keys aside)
- **THEN** the rendered `config.yaml` contains zero `cognito` keys — the opposite outcome (an active `mode: cognito` with placeholder values reaching a customer's rendered output) must not occur
