# Design — GX-24: groundx-on-prem chart support for authenticated Redis

## Goals / Non-Goals

**Goals:**
- Render an optional AUTH password and/or ACL username for each of the three Redis identities the
  chart already tracks separately (`cache`, `cache.metrics`, `ranker.cache`), in the shape each
  consumer already expects (raw YAML for cashbot-go, percent-encoded URL userinfo for ai-server).
- Keep every default-empty render byte-identical to 0.2.7, and every declared key
  schema-validated (`additionalProperties: false` preserved).
- Fail the render, loudly, before any Secret is written, if a credential targets the chart's own
  bundled (uncredentialed) Redis.

**Non-Goals** (see proposal's "Explicitly out of scope"):
- `extract-config-py.yaml` / `workspace-config-py.yaml` broker templates.
- TLS server-certificate verification / mutual TLS.
- Rotating/IAM token auth (ElastiCache IAM, Azure Entra ID).
- No ADR: this is a chart-local template + values-schema change of comparable scope to GX-17
  (which also shipped without one); it introduces no new architecture, service, or external
  dependency.

## Decisions

**Invariant** (gate-class + mechanical-sweep trigger — this change adds a fail-loud render gate
and applies the same credential-rendering edit at 5 template sites): *a rendered credential must
always authenticate the external Redis it was configured for — raw when the consumer decodes YAML,
percent-encoded when the consumer parses a URL — and must never reach the chart's own
bundled, uncredentialed Redis instance.* Every decision below exists to hold that invariant at
every one of the three identities and five template sites, not to satisfy the token "a
password/username key was added somewhere."

### D1 — Credential value locations: top-level (matching db/file/search) plus the `existing` block
`cache.password`/`cache.username` live at the `cache` block's top level, matching the existing
`groundx.db.password` / `groundx.file.password` convention (`db.tpl:50`, `file.tpl:72` — both
`dig "password" "" $in` read directly off the block, not nested under `existing`). `cache.existing`
also gains its own `username`/`password`, alongside the `addr`/`port`/`ssl` fields that already live
there. The resolved credential is `coalesce(existing.password, top-level password)` — `existing`
wins when both are set, matching how `existing.addr`/`existing.ssl` already take priority over
bundled-instance defaults. Two locations (not one) because the schema explicitly needs both declared
(`cache` **and** `cache.existing` both listed in the plan-gate resolution's `additionalProperties`
set) — this gives an operator who is already filling in `cache.existing.{addr,port,ssl}` a natural
place to add the credential alongside them, while keeping the flat `cache.password` slot consistent
with every other backing service in this chart.

The same shape repeats one level down for `cache.metrics`/`cache.metrics.existing` (D2) and, flat
with no `existing` sub-object (mirroring `ranker.tpl`'s existing addr/port/ssl helpers), for
`ranker.cache` (D3).

**Alternative considered**: credential only under `existing` (symmetric with `addr`, which has no
top-level form at all). Rejected because it breaks the explicit plan-gate schema list and the
db/file/search precedent the plan-gate resolution cites by name.

### D2 — Metrics/ranker inherit the main cache credential by default
`groundx.metrics.cache.username`/`.password` resolve `coalesce(metrics.existing.*, metrics.*, groundx.cache.*)`;
`groundx.ranker.cache.username`/`.password` resolve `coalesce(ranker.cache.*, groundx.cache.*)` (no
`existing` sub-object — flat, like `ranker.tpl`'s current addr/port/ssl/isCluster helpers). This is
the same shape `groundx.metrics.cache.addr` and `groundx.ranker.cache.addr` already use to fall back
to the main cache's addr when the identity has no override of its own — the credential fallback
follows the connection-detail fallback exactly, so an operator who already relies on the addr
inheritance gets the credential for free.

### D3 — `ranker.cache.create` (new helper, small, symmetric)
No `groundx.ranker.cache.create` helper exists today because `ranker.cache` never creates its own
bundled instance — it either has its own `addr` (external override, `groundx.ranker.cache.existing
== "true"`) or defers entirely to the main cache. D3 adds that helper (`false` when
`ranker.cache.existing == "true"`; else delegates to `groundx.cache.create`) purely so the fail-loud
guard (D4) has the same "am I pointed at the chart's bundled Redis" signal for the ranker identity
that `groundx.cache.create` / `groundx.metrics.cache.create` already provide for the other two. This
is not new user-facing surface — it is the missing half of an existing fallback pattern, needed by
the guard, not a feature by itself.

### D4 — Fail-loud guard is one helper, called once, checked per identity
`groundx.cache.validateCredentials` checks all three identities against their own bundled-vs-external
signal (`groundx.cache.create`, `groundx.metrics.cache.create`, `groundx.ranker.cache.create`) and
`fail`s naming the offending value the first time a resolved credential is non-empty while that
identity's `*.create == "true"`. It is called once, from `config-yaml.yaml` (unconditionally
rendered, unlike the per-app `*-config-py.yaml` templates, so the guard always fires regardless of
which app components are enabled) — the same "one validate helper, called from the resource
template" shape `groundx.extract.agent.validateImageSettings` already uses
(`extract-agent.tpl:312`, called from `extract-config-py.yaml:17`).

Exact `fail` message per identity (the unittest cases in tasks.md assert these verbatim, so
implement them verbatim):
- cache: `cache.password/cache.username require an external Redis (cache.existing.addr); the chart's own bundled Redis has no AUTH support`
- cache.metrics: `cache.metrics.password/cache.metrics.username require an external Redis (cache.metrics.existing.addr) or an external main cache; the chart's own bundled Redis has no AUTH support`
- ranker.cache: `ranker.cache.password/ranker.cache.username require an external Redis (ranker.cache.addr) or an external main cache; the chart's own bundled Redis has no AUTH support`

**Alternative considered**: a guard per rendering site (config-yaml.yaml, each `*-config-py.yaml`).
Rejected as redundant — every site resolves the same three identities' credentials, so one central
check covers all of them without repeating the bundled/external logic five times.

### D5 — URL userinfo via Sprig `urlquery`; raw value for YAML
This is the AGE-221 spike-derived requirement, not a free design choice: the held spike proved
kombu/redis-py authenticate correctly through URL userinfo including a percent-encoded
reserved-character password, and that an unencoded reserved character breaks URL parsing before
AUTH. `groundx.cache.userinfo` (and the metrics/ranker equivalents) render `"" ` when no password is
set, else `printf "%s:%s@" (username|urlquery) (password|urlquery)` — verified locally
(`helm template` against a scratch chart) that Sprig's `urlquery` matches Go's `url.QueryEscape`
byte-for-byte on a reserved-character password (`p@ss:word/1#` → `p%40ss%3Aword%2F1%23`). The
cashbot-go session blocks never call `urlquery` — cashbot-go's YAML decoder reads the value directly
(`pkg/config/config.go:94,125`), so encoding it would corrupt the credential.

### D6 — Omit the key, don't render it empty
Every new key (`password:`, `username:` in YAML; the userinfo segment in URLs) is wrapped in
`{{- if ne $value "" }}...{{- end }}` rather than always rendering with a possibly-empty value. This
is what makes the default-empty render byte-identical to 0.2.7 (spec's backward-compatibility
scenario) — a rendered `password: ""` would still be a diff from today's render even though it is
functionally inert.

### D7 — `values/values.existing.yaml` documents the new keys as comments, not live values
Verified live (`helm unittest -u`, reverted immediately after) that this environment's installed
`helm-unittest` plugin (1.1.2) regenerates **unrelated** snapshot content when run — even scoped to a
single file with `-f`, `-u` dropped 7 pre-existing entries from `cache_test.yaml.snap` it had just
matched successfully; run unfiltered across the whole chart, it rewrote 9 of 11 `.snap` files
(600+ line-changes in files this change never touches — `api_test.yaml.snap`,
`golang_test.yaml.snap`, `inference_test.yaml.snap`, etc.). This is pre-existing, environment-level
snapshot/plugin-version drift, not something GX-24 introduces (GX-17's own tasks.md already flagged
"a helm-unittest plugin-version formatting change" against other `.snap` files). Consequently, this
design adds the new credential keys to `values/values.existing.yaml` **as commented-out examples**
(`# username: mycacheuser` / `# password: mycachepass`, alongside the existing commented `addr`/
`isCluster`/`port`/`ssl` lines already there) rather than as live values — documenting them for a
reader without changing that file's actual rendered content, so no snapshot needs regenerating and
this change carries zero risk of dragging in the unrelated drift. New behavior is proven instead by
the dedicated `matchRegex`/`failedTemplate` unittest cases (tasks.md), which do not depend on
snapshot matching at all.

## PRODUCER/HYBRID compatibility re-confirmation

Re-read against the actual code (not just the plan-gate outline) at branch time:

- **groundx-on-prem → cashbot-go** (session blocks): confirmed **Additive**. cashbot-go's YAML
  decoder is lenient (`yaml.NewDecoder`, no `KnownFields` — `pkg/config/config.go:94,125`) and its
  consumer side (`config.Redis.User`/`Pass`) is already shipped, via an image containing the
  GX-24 change, and archived. No mechanism needed beyond "the field is optional and ignored if
  unrecognized", which is already true today.
- **groundx-on-prem → ai-server** (Celery broker/result URLs): confirmed **Additive**, per the
  held AGE-221 spike (kombu/redis-py accept URL userinfo with no code change).
- **groundx-on-prem → ai-server** (`status.py` / `metricsBroker`): confirmed **Breaking for an
  un-updated image**, exactly as contract.md records — `status.py`'s hand-rolled URL parser does not
  strip userinfo, so a credentialed `metricsBroker` would misparse on an ai-server image that does
  not yet contain the GX-24 change. The compatibility mechanism is the **default-empty gate** (D6)
  plus the **fail-loud guard** (D4) — there is no versioned-field or feature-flag mechanism
  available at the chart-values layer for this case, and none is needed: an operator cannot reach
  the breaking path unless they explicitly set a credential, and the release-management ordering
  constraint (chart PR must not merge before an ai-server image containing the GX-24 change is
  what 0.2.7 advertises) is already recorded in the proposal's
  Impact section as the actual mitigation, not a chart mechanic. This re-confirms — does not
  change — the contract.md classification; `contract_section` (produced at apply time, per the
  apply-mode contract) will point back to the actual rendered shapes once implemented.

No touchpoint's classification changed as a result of re-reading the code — the plan-gate outline
already matched what the templates and helpers show.

## Risks / Trade-offs

- **[Risk] The installed `helm-unittest` plugin version produces unrelated snapshot churn on
  `-u`, discovered while scoping this change (see D7).** This is a pre-existing environment/tooling
  gap, not a GX-24 defect — it blocks safely regenerating ANY snapshot in this environment right now,
  which is why this design avoids `matchSnapshot` for every new case and avoids adding live
  (non-commented) values to `values/values.existing.yaml`. → Mitigation: none of this change's new
  tests depend on snapshot matching, so this change ships with zero snapshot deltas. No ticket exists
  yet for the underlying plugin/pin mismatch — flagging it here is not a claim that one does; if the
  team wants it tracked, that is a separate decision, not made by this change.

- **[Risk] An operator sets `cache.metrics.password` while `cache.metrics.enabled=true` and no
  `cache.metrics.existing.addr`, not realizing the metrics identity has its own bundled instance
  distinct from the main cache.** → Mitigation: D4's guard checks `groundx.metrics.cache.create`
  specifically (not just the main cache's), so this exact case fails loudly rather than silently
  targeting an uncredentialed pod.
- **[Risk] `helm/` mirror drifts from `src/groundx` for this specific delta** (the mirror already
  carries pre-existing, unrelated drift — Chart.yaml version, one memory value). → Mitigation: the
  mirror-parity spec requirement plus a task that diffs the two template trees for exactly the files
  this change touches (not a full-tree diff, which would also flag the pre-existing drift this
  change is not scoped to fix).
- **[Risk] Sprig `urlquery`'s exact escaping does not match what `urllib.parse.urlsplit` expects on
  every possible character** (verified only for the one reserved-character password class the spike
  and this design tested). → Mitigation: the spike's semantics basis already covers this
  (`urlsplit`'s `.username`/`.password` are percent-decoded), and the new unittest cases assert the
  specific round-trip; a character class discovered later to misbehave is a follow-up, not a
  reason to withhold this change (no ticket exists yet for that follow-up — none is claimed here).

## Migration Plan

No schema or data migration. Purely additive template + values-schema logic behind default-empty
values (per spec's backward-compatibility scenario). An upgrade that sets a credential changes the
rendered Secret content, which triggers the existing `config-hash` pod-restart mechanism — no new
rollout mechanism introduced. `helm rollback` reverses cleanly (proposal's Impact section already
covers rollback/rollforward; not repeated here). The one ordering constraint — this chart PR must not
merge before the ai-server 0.2.7-release image is an image containing the GX-24 change (the
`status.py` fix) — is a
release-management fact recorded in the proposal, not something this design can enforce from inside
the chart.

## Open Questions

None. The plan-gate resolutions (E1-A, E2-A, the per-identity-with-fallback shape, the
percent-encoding requirement) already fixed scope and shape; D1–D6 above are the concrete rendering
decisions that implement them without exceeding them.

## Amendments (apply phase, 2026-09-01)

- **D4 attribution nuance (not a scope or logic change):** `groundx.cache.validateCredentials`
  stayed a single helper called only from `config-yaml.yaml`, exactly as D4 specified — no second
  call site was added. Verified live (`helm template`) that Helm's chart-wide render, when more
  than one top-level template would independently `fail`, surfaces only the error from whichever
  file executes last in its internal ordering, which is not `config-yaml.yaml`. That is a Helm
  rendering-order artifact affecting which file's location a `helm template`/`helm install` error
  message cites — it does not change *whether* the render fails (it always does, for every
  violation, in every real invocation). The one authored `helm unittest` case that renders
  `ranker-config-py.yaml` in isolation was retargeted to `config-yaml.yaml` (matching the pattern
  its two sibling test files already use for their own fail-loud cases) so the assertion checks the
  file that actually performs the guard, per D4.
- **`groundx.cache.password`/`.username` (and the metrics/ranker equivalents) append `| default ""`
  after `coalesce`.** Verified live: Sprig's `coalesce` returns Go `nil` (not `""`) when every
  argument is empty, and piping that `nil` into another function (`urlquery`, used by
  `groundx.cache.userinfo`) renders the literal text `<no value>` — normally invisible in a
  directly-printed value because Helm's engine string-replaces `<no value>` in the final rendered
  output, but that replacement never reaches a value that has already been percent-encoded into
  `%3Cno+value%3E`. `default ""` normalizes the coalesce result to a real empty string before any
  further piping, which is what keeps the default (unset) render byte-identical.
- **`tests/cache_metrics_credentials_test.yaml` and `tests/ranker_cache_credentials_test.yaml`**:
  one `notMatchRegex` assertion each, in the "an identity's own credential overrides the inherited
  main cache credential" case, was narrowed from a whole-file substring check (`"mainpass"`) to the
  specific broker field (`'metricsBroker="redis://:mainpass@'` / `'searchBroker="redis://:mainpass@'`).
  The whole-file form was a false negative against *correct* behavior: the same rendered document
  legitimately carries the main cache's own credential on its own `layoutBroker`/`searchBroker`
  entry, which the original pattern could not distinguish from a leak into the identity under test.
- **`verify-mirror-parity.sh`** now strips the three Chart.yaml-derived default-label lines
  (`appVersion`/`chart`/`version`) before comparing the two renders. `helm/`'s `Chart.yaml` carries
  a pre-existing, unrelated version drift (0.2.6 vs `src/groundx`'s 0.2.7 — noted in this design's
  Risks and in proposal.md) that the script's original byte-for-byte comparison had no way to
  exclude, so it failed on every case regardless of credential-render parity. A deliberately
  broken mirror file was used to confirm the narrowed comparison still catches a real mismatch
  before this fix was kept.

## Amendments (review round 1, 2026-09-01)

Five review findings changed rendering behavior (D4's guard predicate, D2/D3's inheritance
predicate, and userinfo encoding); recorded here rather than rewritten into D1–D7 above, which
describe what the plan-gate resolutions actually decided at authoring time.

- **F1 — metrics/ranker credential inheritance now gates on the same predicate the addr helpers
  use, not unconditionally.** `groundx.metrics.cache.password`/`.username` and
  `groundx.ranker.cache.password`/`.username` previously fell back to the main cache's credential
  whenever the identity had no credential of its own, regardless of whether the identity had its
  *own* external `existing.addr`/`addr`. `values.existing.yaml`'s own configuration (two distinct
  external Redis addresses, main and metrics, one credential set on main) triggered this: the
  metrics identity would render the main cache's credential against a different host. The fix:
  when the identity has its own external address, its resolved credential is its own value only
  (no main fallback) — an identity pointed at its own external Redis with no credential of its own
  now renders no credential, never someone else's.
- **F4 — the fail-loud guard (D4) now keys on the identity's resolved externality
  (`groundx.<identity>.cache.isExternal`), not `groundx.<identity>.cache.create`.** Two silent
  cases existed under the `create`-keyed guard: (i) `cache.enabled: false` with no
  `existing.addr` resolved `create` to `false` (the `enabled` flag short-circuited the check)
  while the identity's address still resolved to the chart's own bundled DNS name, silently
  rendering a credential there; (ii) an external main cache with a bundled (default-enabled)
  metrics identity made `groundx.metrics.cache.create` delegate to the *main* identity's
  create/external state, so a metrics credential inherited from an external main cache rendered
  silently at the metrics identity's own bundled pod (`cache-metrics.<ns>`), which has no AUTH
  support. `isExternal` is derived purely from the identity's own resolved address (mirroring the
  addr helper's own branching), independent of the other identities' state.
- **F3 — userinfo encoding is `urlquery` followed by `replace "+" "%20"` (`groundx.redis.
  userinfoEscape`), not bare `urlquery`.** `urlquery` (Go's `url.QueryEscape`) encodes a space as
  `+`; a URL userinfo decoder (`urllib.parse.unquote`, the ai-server/Python side, and any
  standards-conformant URL userinfo parser) leaves a literal `+` as `+`, not a space — so a
  space-containing password decoded to the wrong value on the consumer side. `openspec/config.yaml`'s
  durable convention (the "URL-EMBEDDING A CREDENTIAL" line) is corrected to match, and also
  corrects the `urlquery` attribution: it is a Go `text/template` builtin, not a Sprig function.
- **F5 — a username with no password (nopass ACL) is rejected for all three identities,
  independent of the bundled-vs-external check.** Per human decision (a): the chart's Secret
  rendering path has no in-chart mechanism to express a nopass ACL for the ai-server broker-URL
  consumer shape, so `validateCredentials` now also `fail`s when a username is set with an empty
  password on an otherwise-external identity, naming the offending identity.
- **F12 — `groundx.redis.yamlScalar` is unconditional `| quote`,** replacing the
  `regexMatch`-gated conditional quoting (quote only when the value contains a character outside
  `[A-Za-z0-9_.-]`). Per human decision (c): always-quoted YAML scalars are simpler to reason
  about and equally valid YAML; the conditional form saved a few bytes on the common case at the
  cost of two code paths to verify instead of one.

The round's test-file, `tasks.md`, and `openspec/config.yaml` corrections (including the F6
round-trip decode check, the F7 archive-stable `verify-mirror-parity.sh` check path, and the F10
both-mirrors-fail-identically case) are described inline at their respective task entries in
`tasks.md` rather than repeated here.
