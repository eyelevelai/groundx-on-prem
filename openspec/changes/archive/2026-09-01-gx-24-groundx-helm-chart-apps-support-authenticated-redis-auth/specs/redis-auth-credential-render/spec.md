## ADDED Requirements

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
  userinfo-safe URL-quoting function (`urlquery` followed by `replace "+" "%20"` — plain `urlquery`
  alone encodes a space as `+`, which a userinfo decoder leaves literal; review round 1 finding F3)
- **AND THEN** the encoded URL parses to the same host/port/path as the credential-free form —
  proving the reserved characters no longer break URL parsing before AUTH is attempted

#### Scenario: a real URL decoder round-trips the encoded userinfo back to the configured value, including a space (polarity: finalize success — review round 1 finding F6)
- **GIVEN** `cache.password` is set to a value containing a space (e.g. `"my pass"`)
- **WHEN** the rendered broker URL's userinfo segment is decoded by a real URL parser
  (`urllib.parse.urlsplit` + `unquote`, matching the ai-server consumer)
- **THEN** the decoded password equals the exact configured value, `"my pass"`, not a value with a
  literal `+` in place of the space

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
`ranker.cache.username`/`.password`) and, **only when the identity has no external address of its
own** (`cache.metrics.existing.addr` unset, or `ranker.cache.addr` unset), SHALL fall back to the
resolved main `cache` credential — the same predicate their existing `addr`/`port`/`ssl` helpers
already use to decide whether the identity inherits the main address. An identity with its own
external address and no credential of its own SHALL resolve to **no credential**, not the main
cache's — the main credential authenticates the main cache's own Redis, not a different host
(review round 1 finding F1; `values.existing.yaml`'s own configuration, two distinct external
Redis addresses with only the main one credentialed, is the case this gate exists for).

#### Scenario: an identity with no credential of its own inherits the main cache credential
- **GIVEN** `cache.password` is set and `cache.metrics` sets no credential of its own and no
  `existing.addr` of its own (so it inherits the main address too)
- **WHEN** `layout-config-py.yaml`'s `metricsBroker` URL renders
- **THEN** it carries the main cache's credential, percent-encoded, exactly as `groundx.metrics.cache.addr`
  already falls back to `groundx.cache.addr` when metrics has no `existing.addr` of its own

#### Scenario: an identity's own credential overrides the inherited one
- **GIVEN** `cache.password` is set AND `ranker.cache.addr` and `ranker.cache.password` are also set
  to a different value
- **WHEN** `ranker-config-py.yaml`'s `searchBroker`/`searchResultBroker` URLs render
- **THEN** they carry `ranker.cache`'s own credential, not the main cache's

#### Scenario: an identity with its own external address but no credential of its own renders no credential (polarity: reject before state — review round 1 finding F1)
- **GIVEN** `cache.password` is set on the main cache AND `cache.metrics.existing.addr` (or
  `ranker.cache.addr`) is set to a *different* host, with no credential of its own
- **WHEN** the identity's broker URL renders
- **THEN** it carries no userinfo segment at all — the main cache's credential is NOT inherited,
  because it would authenticate the wrong host

### Requirement: A credential targeting the chart's own bundled Redis fails the render before any Secret is written
Credentials apply to an **external** Redis only: if a credential value (password and/or username) is set for an identity whose *own resolved address* is the chart's own bundled, uncredentialed Redis (`groundx.cache.isExternal`, `groundx.metrics.cache.isExternal`, or `groundx.ranker.cache.isExternal`, all `!= "true"` — each derived from the identity's own resolved address, not from another identity's `enabled`/`create` state), the chart SHALL fail the render (Helm `fail`) with a message naming the offending value and the external-only requirement, rather than silently emitting a Secret carrying a credential the bundled instance cannot use. A username set with no password (nopass ACL) is rejected for every identity, independent of the bundled-vs-external check — the chart's Secret-backed rendering has no mechanism to express a nopass ACL.

#### Scenario: a credential on the bundled cache is caught (polarity: catches — invariant-first adversarial case)
- **GIVEN** `cache.password` is set and `cache.existing.addr` is unset (the chart creates its own cache)
- **WHEN** the chart is rendered (`helm template` or `helm install`)
- **THEN** the render fails with a `fail` error identifying `cache.password`/`cache.username` as
  requiring an external Redis
- **AND THEN** no `config-yaml-map` or `*-config-py-map` Secret is emitted carrying the credential

#### Scenario: an identity's own resolved address, not another identity's state, decides the guard (polarity: catches — review round 1 finding F4)
- **GIVEN** the main `cache` is external (`cache.existing.addr` set with no credential) and
  `cache.metrics` is left at its default (enabled, no `existing.addr` of its own, so it resolves
  to its own bundled pod) with `cache.metrics.password` set
- **WHEN** the chart is rendered
- **THEN** the render fails identifying `cache.metrics.password`/`cache.metrics.username` as
  requiring an external Redis — the main cache being external does not exempt the metrics
  identity, whose own resolved address is still the chart's own bundled pod

#### Scenario: a disabled bundled identity with no external address still fails loudly (polarity: catches — review round 1 finding F4)
- **GIVEN** `cache.enabled` is `false` and `cache.existing.addr` is unset, and `cache.password` is set
- **WHEN** the chart is rendered
- **THEN** the render fails identifying `cache.password`/`cache.username` as requiring an external
  Redis — `cache.enabled: false` does not exempt the guard, because the identity's resolved
  address is still the chart's own bundled DNS name, not an external Redis

#### Scenario: a username with no password is rejected even on an external identity (polarity: catches — review round 1 finding F5, human decision (a))
- **GIVEN** `cache.existing.addr` is set (the cache is external) and `cache.username` is set with
  no `cache.password`
- **WHEN** the chart is rendered
- **THEN** the render fails identifying `cache.username` as requiring `cache.password` — a nopass
  ACL is not supported by this chart's Secret-backed rendering

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
