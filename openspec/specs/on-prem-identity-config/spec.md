# on-prem-identity-config Specification

## Purpose
Define chart configuration and operator documentation for API-key-only, Cognito, and local password identity modes.
## Requirements
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

`docs/on-prem-identity.md` SHALL state the default `apiKeyOnly` identity behavior, the optional `cognito` mode and its required keys, the optional `local` mode and its compatible-server requirement, and the air-gapped choices (`apiKeyOnly` or `local`; `mode: cognito` requires reaching AWS Cognito, which an air-gapped cluster cannot do). It SHALL also document the `local` mode password path as hardened by GX-83, covering:

- the per-account lock: three failed password attempts lock that account for 15 minutes, every spelling of the account's email that the database treats as equal and the account's username share one count, a locked or failed attempt returns the same generic error as any other failed login, and a successful login or an admin password reset clears the count;
- a sustained-lockout warning: anyone who knows an email can re-lock it every 15 minutes; per-source-IP ingress rate limits set through `groundx.ingress.annotations` slow brute-force guessing but are no defence against a targeted lockout of a known email (accepted residual), and an admin password reset is the recovery;
- the API-key option on the MCP authorize page, for customers who have no password yet;
- the scope of a password reset: it ends that customer's MCP sessions only, and after a compromise the operator must disable the account and reset its password (disabling can take up to an hour to reach cached credentials), since deleting API keys alone does not help (the username still works as a credential, GX-113);
- Redis behaviour: a failover right after a reset can revive MCP sessions that reset ended (accepted residual), and a Redis `maxmemory-policy` of `noeviction` or `volatile-*` is recommended because under `allkeys-*` a revocation marker can be evicted, and the operator checks it with `redis-cli CONFIG GET maxmemory-policy` since the chart has no setting for it;
- MCP sign-in on chart installs depends on GX-112, and the sign-up link is hidden on chart installs until then;
- the requirement for a cashbot-go image that includes GX-83, and a one-line note that after upgrading to such an image existing local-mode MCP sessions must re-authorize once.

The document SHALL NOT contain the pre-GX-83 statements that nothing throttles password attempts or that MCP sign-in cannot authorize a customer until a password is set.

#### Scenario: The identity-story doc covers supported modes and air-gapped choices (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** `docs/on-prem-identity.md` is inspected
- **THEN** it states the `apiKeyOnly` default, documents the `cognito.*` keys required to opt into `mode: cognito`, documents `mode: local` and its compatible-server requirement, and states that air-gapped installs can use `apiKeyOnly` or `local` but not `mode: cognito`

#### Scenario: The doc describes the lock and the uniform response (polarity: reject before state)

- **GIVEN** this change is applied
- **WHEN** the `local` section of `docs/on-prem-identity.md` is inspected
- **THEN** it states that three failed attempts lock the account for 15 minutes and that a locked attempt gets the same generic error as any failed login
- **AND THEN** it does not state or imply that a locked attempt is counted, extends the lock, or reveals whether the email exists

#### Scenario: The doc warns about sustained lockout and names the defence (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it warns that anyone who knows an email can re-lock it every 15 minutes, names per-source-IP ingress rate limits via `groundx.ingress.annotations` as slowing brute-force guessing but no defence against a targeted lockout (accepted residual), and names an admin password reset as the recovery

#### Scenario: The doc limits what a reset revokes (polarity: finalize failure — the reset does not end API-key access)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it states a reset ends that customer's MCP sessions only and tells the operator to disable the account and reset its password after a compromise, noting disabling can take up to an hour to take effect, since deleting API keys alone does not help (GX-113)
- **AND THEN** it does not claim a reset revokes API keys or app sessions

#### Scenario: The doc states the Redis caveats (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it describes the failover edge case (sessions ended by a reset can be revived) and recommends `noeviction` or `volatile-*`, stating that `allkeys-*` can evict the revocation marker

#### Scenario: The doc does not claim chart support for MCP sign-in (polarity: skip unrelated repair path)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it states MCP sign-in on chart installs needs GX-112 and the sign-up link is hidden until then
- **AND THEN** it does not claim the chart exposes an MCP token secret or a sign-up URL value

#### Scenario: The doc states the image requirement and the one-time re-authorization (backward compatibility — cross-service touchpoint)

- **GIVEN** an install running a cashbot-go image from before GX-83, or one on `apiKeyOnly` or `cognito` mode
- **WHEN** the operator reads `docs/on-prem-identity.md`
- **THEN** the doc states the `local` lock and revocation behavior needs a cashbot-go image that includes GX-83, and that after upgrading to such an image existing local-mode MCP sessions must re-authorize once
- **AND THEN** the `apiKeyOnly`, `cognito` and rollback sections are unchanged

#### Scenario: Stale pre-GX-83 statements are absent (polarity: reject before state)

- **GIVEN** this change is applied
- **WHEN** `docs/on-prem-identity.md` is searched for "Nothing throttles password attempts" and for the statement that MCP sign-in cannot authorize until a password is set
- **THEN** neither is found

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

