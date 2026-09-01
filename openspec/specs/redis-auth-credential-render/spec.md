# redis-auth-credential-render Specification

## Purpose
TBD - created by archiving change gx-24-groundx-helm-chart-apps-support-authenticated-redis-auth. Update Purpose after archive.
## Requirements
### Requirement: Chart renders Secret-backed Redis AUTH credentials, encoded per consumer shape
For each of the three Redis identities the chart already models separately (`cache`, `cache.metrics`, `ranker.cache`), the chart SHALL render an optional AUTH password and/or ACL username, sourced from chart values and delivered only through the existing Secret-backed config resources (`config-yaml-map`, the `*-config-py-map`s). The cashbot-go `session:` blocks in `config-yaml-map` SHALL carry the raw, unencoded credential as `password:`/`username:` YAML keys. The ai-server broker/result-backend/metrics URLs in the `*-config-py-map`s SHALL carry the credential percent-encoded as URL userinfo (`scheme://[username]:password@host:port/0`). A key SHALL be omitted entirely, not rendered empty, when its value is unset.

#### Scenario: cashbot-go session block renders the raw credential (polarity: finalize success)
- **GIVEN** `cache.password` and `cache.username` are set for an external cache
- **WHEN** `config-yaml.yaml` renders the `rec.session` (or `metrics.session`) block
- **THEN** the block carries `password: <raw value>` and `username: <raw value>`, unencoded
- **AND THEN** no percent-encoding is applied — cashbot-go decodes YAML, not a URL

#### Scenario: ai-server broker URL renders a percent-encoded credential (polarity: finalize success)
- **GIVEN** `cache.password` is set to a value containing URL-reserved characters (e.g. `@`, `:`, `/`, `#`)
- **WHEN** `layout-config-py.yaml`, `ranker-config-py.yaml`, or `summary-config-py.yaml` renders a
  broker, result-backend, or `metricsBroker` URL for that identity
- **THEN** the userinfo segment (`[username]:password@`) is percent-encoded via the chart's
  URL-quoting function
- **AND THEN** the encoded URL parses to the same host/port/path as the credential-free form —
  proving the reserved characters no longer break URL parsing before AUTH is attempted

#### Scenario: an unencoded reserved-character password is caught (polarity: catches — invariant-first adversarial case)
- **GIVEN** `cache.password` is `p@ss:word/1#` (URL-reserved characters, no encoding applied)
- **WHEN** the rendered broker URL is parsed as a URL (e.g. by `urllib.parse.urlsplit`, matching the
  ai-server consumer)
- **THEN** an unencoded render would split the host/port incorrectly or drop segments of the password
  before AUTH is ever attempted
- **AND THEN** the chart's actual render (percent-encoded userinfo) parses back to the exact original
  password and the correct host/port — the adversarial case the invariant exists to prevent

#### Scenario: default-empty renders are byte-identical to 0.2.7 (polarity: must-not-block / backward-compatibility)
- **GIVEN** no `cache.password`, `cache.username`, `cache.metrics.*`, or `ranker.cache.*` credential
  value is set anywhere (today's default)
- **WHEN** `config-yaml.yaml`, `layout-config-py.yaml`, `ranker-config-py.yaml`, and
  `summary-config-py.yaml` render, for both `src/groundx` and the `helm/` mirror
- **THEN** the rendered manifests are byte-identical to the pre-GX-24 (0.2.7) render — no
  `password:`/`username:` key appears in any session block, and every broker/result/metrics URL
  keeps its credential-free `scheme://host:port/0` form
- **AND THEN** an auth-less-Redis install upgrading through this chart version keeps working exactly
  as before, with no code change required on either consumer (cashbot-go, ai-server)

### Requirement: Metrics and ranker Redis identities inherit the main cache credential, with a per-identity override
`cache.metrics` and `ranker.cache` SHALL resolve their own credential from their own value location
first (`cache.metrics.existing.username`/`.password`, then `cache.metrics.username`/`.password`; or
`ranker.cache.username`/`.password`) and, only when none of those are set, SHALL fall back to the
resolved main `cache` credential — the same fallback shape their existing `addr`/`port`/`ssl` helpers
already use.

#### Scenario: an identity with no credential of its own inherits the main cache credential
- **GIVEN** `cache.password` is set and `cache.metrics` sets no credential of its own
- **WHEN** `layout-config-py.yaml`'s `metricsBroker` URL renders
- **THEN** it carries the main cache's credential, percent-encoded, exactly as `groundx.metrics.cache.addr`
  already falls back to `groundx.cache.addr` when metrics has no `existing.addr` of its own

#### Scenario: an identity's own credential overrides the inherited one
- **GIVEN** `cache.password` is set AND `ranker.cache.addr` and `ranker.cache.password` are also set
  to a different value
- **WHEN** `ranker-config-py.yaml`'s `searchBroker`/`searchResultBroker` URLs render
- **THEN** they carry `ranker.cache`'s own credential, not the main cache's

### Requirement: A credential targeting the chart's own bundled Redis fails the render before any Secret is written
Credentials apply to an **external** Redis only: if a credential value (password and/or username) is set for an identity that resolves to the chart's own bundled, uncredentialed Redis (`groundx.cache.create`, `groundx.metrics.cache.create`, or the ranker identity falling back to a chart-created cache, all `== "true"`), the chart SHALL fail the render (Helm `fail`) with a message naming the offending value and the external-only requirement, rather than silently emitting a Secret carrying a credential the bundled instance cannot use.

#### Scenario: a credential on the bundled cache is caught (polarity: catches — invariant-first adversarial case)
- **GIVEN** `cache.password` is set and `cache.existing.addr` is unset (the chart creates its own cache)
- **WHEN** the chart is rendered (`helm template` or `helm install`)
- **THEN** the render fails with a `fail` error identifying `cache.password`/`cache.username` as
  requiring an external Redis
- **AND THEN** no `config-yaml-map` or `*-config-py-map` Secret is emitted carrying the credential

#### Scenario: a credential on an external cache is not blocked (polarity: must-not-block)
- **GIVEN** `cache.password` is set and `cache.existing.addr` is also set (the cache is external)
- **WHEN** the chart is rendered
- **THEN** the render succeeds and the credential appears in the rendered Secrets exactly as specified
  in the requirement above
- **AND THEN** the fail-loud gate that catches the bundled case does not fire for this legitimate case

### Requirement: Every new credential key is declared in the values schema
`values.schema.json` SHALL declare `username` and `password` (type `string`) on `cache`,
`cache.existing`, `cache.metrics`, `cache.metrics.existing`, and `ranker.cache`, preserving
`additionalProperties: false` on each of those objects and on the schema root.

#### Scenario: an undeclared credential key hard-fails the render
- **GIVEN** a values file sets a key not declared by the schema (e.g. a typo'd `cache.passwrod`)
- **WHEN** the chart is rendered
- **THEN** Helm's schema validation rejects the values before any template executes

#### Scenario: every declared credential key renders when set
- **GIVEN** each of `cache.username`, `cache.password`, `cache.existing.username`,
  `cache.existing.password`, `cache.metrics.username`, `cache.metrics.password`,
  `cache.metrics.existing.username`, `cache.metrics.existing.password`, `ranker.cache.username`,
  and `ranker.cache.password` is set in turn
- **WHEN** the chart is rendered
- **THEN** schema validation accepts the values and the corresponding identity's resolved credential
  reflects the set value

### Requirement: Both chart mirrors render the credential behavior identically
The `src/groundx` source chart and the `helm/` manual mirror SHALL apply the identical credential
rendering, inheritance, percent-encoding, and fail-loud template logic, and SHALL produce identical
rendered output for the same values.

#### Scenario: both mirrors render the same credentialed output
- **GIVEN** the same values setting `cache.password`, `cache.username`, and an external `cache.existing.addr`
- **WHEN** `helm template` renders `src/groundx` and, independently, `helm/`
- **THEN** the rendered `config-yaml-map` and `*-config-py-map` Secret contents are identical between
  the two chart surfaces

#### Scenario: both mirrors fail identically on the bundled-cache case
- **GIVEN** `cache.password` is set with no `cache.existing.addr`
- **WHEN** `helm template` renders `src/groundx` and, independently, `helm/`
- **THEN** both renders fail with the same `fail` error

