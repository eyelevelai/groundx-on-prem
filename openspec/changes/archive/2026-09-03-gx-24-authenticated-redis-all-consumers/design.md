## Goals / Non-Goals

See `proposal.md` for the full current-state citations (file:line) this design builds on; this
document records only the decisions and their rationale.

**Goals:**
- Render an optional AUTH password / ACL username, per cache identity, inline into the config
  resources that are already `kind: Secret` on 0.2.7, so every Redis-consuming workload this chart
  configures (cashbot-go's shared session client, and every Celery broker/result URL: layout,
  summary, extract, ranker, workspace) can authenticate to a customer's AUTH/ACL-protected Redis.
- Keep the credential-less path byte-identical to 0.2.7 in both chart mirrors (`src/groundx/` and
  `helm/`).
- Land the "at least one full-chart test extending an existing values file" requirement from Ben's
  comment 756aee1c as an executable, non-snapshot assertion (not only an implicit snapshot diff).

**Non-Goals (out of scope for this chart change, tracked elsewhere per the workspace cross-service
design and the ticket's own Out-of-scope section):**
- cashbot-go's `Username` field, ai-server's `status.py` credential parse, and the
  internal-arcadia-agents / groundx-workspace-runner broker-URL verifications — separate repos'
  OpenSpec changes.
- TLS server-certificate verification / mTLS (pre-existing, unrelated to auth).
- Rotating/IAM-style token auth (ElastiCache IAM, Azure Entra ID) — needs a credentials-provider
  callback, not a static Secret value; a distinct effort.
- Any new Secret resource, `existingSecret` reference, `envFrom`/`secretRef` delivery, or a
  fail-loud "username requires password" guard — all explicitly rejected paradigms (Ben, GX-17).
- No new ADR: the credential-delivery paradigm (config-file-as-Secret) is the GX-17-accepted
  pattern already implemented in this chart (`db.password`/`search.password` inline into
  `config-yaml.yaml`); this change extends that existing pattern to a fourth value (`cache`) and
  three more identities, it does not introduce a new architectural decision. GX-17 itself shipped
  with no ADR (`docs/adr/` does not exist in this repo) — this change follows that precedent. The
  cross-service decisions (R1/R2/R3) are recorded once, in the **workspace-level** (not this
  repo's) `openspec/changes/gx-24-authenticated-redis-all-consumers/design.md`, and are referenced
  here rather than restated.

## Decisions

- **Invariant (this change edits the same `printf "%s://%s:%v/0"` → `printf "%s://%s%s:%v/0"`
  shape at nine broker/result-URL call sites, so the sweep must be checked against its meaning,
  not its token — see "Invariant-first" in the builder's operating rules): at every call site, the
  URL's userinfo fragment must carry the credential of the exact Redis instance that call site's
  own `addr`/`scheme`/`port` already resolve to — each site's `userinfo` helper must be that same
  identity's own helper (`groundx.ranker.cache.userinfo` at a `groundx.ranker.cache.addr` call
  site, never `groundx.cache.userinfo` copy-pasted in because the printf shape looks the same) —
  never a different identity's credential, and never any credential when that identity has none
  configured.** A call site that renders the *main* cache's credential while its `addr` resolves
  to a *different*, separately-authenticated instance would satisfy the mechanical shape (a
  `%s%s` fragment is present) while authenticating with the wrong password — the identity-specific
  helper name at each site is what the invariant, not the shape, actually depends on.

- **Mirror `groundx.db.password` exactly for the new `groundx.cache.password` /
  `groundx.cache.username` helpers.** `groundx.db.password` is a one-line `dig "password" "" $in`
  against `.Values.db` (`templates/_helpers/services/db.tpl`) with no `existing`-block
  indirection — `db.password`/`search.password` render the same whether or not `db.existing`/
  `search.existing` is set. `cache.password`/`cache.username` follow the identical shape against
  `.Values.cache`, added to `templates/_helpers/services/cache.tpl`. Alternative considered:
  nesting under `cache.existing.password` per this ticket's original (now-superseded) plan —
  rejected because it does not match the `db`/`search` precedent Ben pointed at, and it would only
  be settable for external Redis, not the chart-deployed one (a customer could equally want the
  chart's own Redis to require auth).

- **R1 — per-identity fallback exactly mirrors that identity's existing `addr` fallback (workspace
  design decision, confirmed against this repo's code).** Three helper pairs are added, each
  reusing the same conditional its identity's `addr`/`existing` helper already uses:
  - `groundx.metrics.cache.password`/`username` — own value from `.Values.cache.metrics` when
    `cache.metrics.enabled` is true (the exact condition `groundx.metrics.cache.addr` already
    branches on to decide "metrics has its own instance" vs. "metrics shares the main cache
    service"); otherwise `include "groundx.cache.password"`. This makes the *value* fallback
    track the *address* fallback file-for-file, so a rendered credential can never end up paired
    with the wrong Redis instance.
  - `groundx.ranker.cache.password`/`username` — own value from `.Values.ranker.cache` when
    `groundx.ranker.cache.existing` is `"true"` (ranker has a configured `cache.addr`, the same
    gate `groundx.ranker.cache.addr` uses); otherwise `include "groundx.cache.password"`.
  - No new helper is needed for the main `cache` identity itself — it has no fallback, only a
    source.
  Alternative considered: a single generic `groundx.cache.credentialFor` helper parameterized by
  identity — rejected as premature abstraction: the chart's own existing style already duplicates
  the near-identical `scheme`/`ssl`/`notCluster`/`isCluster` helper bodies per identity (see
  `cache.tpl` `groundx.metrics.cache.scheme` vs `groundx.cache.scheme`, and `ranker.tpl`
  `groundx.ranker.cache.scheme`); a generic helper would be the only genericized piece surrounded
  by three already-duplicated siblings, adding an inconsistency rather than removing one.

- **Percent-encode with Sprig `urlquery`, wrapped in a per-identity `userinfo` helper that returns
  the full `user:pass@` / `pass@` / `""` fragment.** Confirmed against this Helm's Sprig build
  (`helm template` smoke: `urlquery "cache-p@ss:w0rd"` → `cache-p%40ss%3Aw0rd`) — reserved
  userinfo characters (`@`, `:`, `/`) survive. Each identity gets its own `groundx.<id>.userinfo`
  helper (`groundx.cache.userinfo`, `groundx.metrics.cache.userinfo`,
  `groundx.ranker.cache.userinfo`) returning `""` when no password is set, so every broker/result
  URL construction changes from `printf "%s://%s:%v/0" scheme addr port` to
  `printf "%s://%s%s:%v/0" scheme userinfo addr port` — a minimal, mechanical edit at each of the
  nine call sites (`layout-config-py.yaml` x2, `summary-config-py.yaml` x2,
  `extract-config-py.yaml` x1, `ranker-config-py.yaml` x2, plus the two `workspace.tpl` helpers),
  with no change to the surrounding `printf` shape. The plain `config-yaml.yaml` session blocks
  (cashbot-go, read as discrete YAML fields, not a URL) use the unencoded `password`/`username`
  helpers directly — no `userinfo`/URL construction there.

- **GX-17 gate-unblocking fix (recorded, pre-existing, unrelated to GX-24's own scope): `tests/resources_test.yaml`'s two `path: data["config.yaml"]` assertions are corrected to `path: stringData["config.yaml"]`.** GX-17 converted `config-yaml.yaml` to `kind: Secret` (`stringData`), but left these two assertions reading the old `ConfigMap`-shaped `data` path, so they fail on 0.2.7 independent of this change (confirmed: `helm unittest -f 'tests/resources_test.yaml' src/groundx` fails on this branch's base commit with `unknown path data["config.yaml"]`). Fixed here only because it blocks the full-suite green gate this change's acceptance criterion requires; no other line in that file is touched. `helm/tests/` does not exist in this repo (the published mirror ships with `tests/` removed, per this repo's own `AGENTS.md`), so there is no matching `helm/tests/resources_test.yaml` to fix — the fix applies to `src/groundx/` only.

- **R2 refinement — per-field credential injection for the two workspace Celery URLs.** Each of `celeryBrokerUrl` and `celeryResultBackend` is gated independently: its own fallback branch carries the main-cache credential unless that specific field is operator-supplied. Two helpers, `groundx.workspace.celeryBrokerUrlManaged` and `groundx.workspace.celeryResultBackendManaged`, each true only when its own field is non-empty, gate the `userinfo` fragment for its own fallback. So an operator who overrides only `celeryBrokerUrl` keeps the credentialed chart-built `celeryResultBackend` fallback (the result backend still authenticates against the AUTH-protected main cache), while a full operator-supplied URL on either field is never rewritten. This replaces the earlier all-or-nothing gate (a single shared `celeryUserManaged` helper that suppressed both fallbacks whenever either field was set), which dropped the credential from a defaulted sibling URL on a partial override. The acceptance test `tests/redis-auth_test.yaml` covers both the full-override (never-rewritten) case and the partial-override (sibling fallback still credentialed) case.

- **R2 — workspace credential injection is confined to the existing fallback branch.**
  `groundx.workspace.celeryBrokerUrl`/`celeryResultBackend` already `coalesce` a user-supplied
  `workspace.celeryBrokerUrl`/`celeryResultBackend` over a chart-built `$fallback`. Only
  `$fallback`'s `printf` gains the `groundx.cache.userinfo` fragment; the `coalesce` itself, and
  therefore a user-supplied full URL, is untouched. This is the one call site where "add
  `userinfo` to the printf" is not sufficient on its own to state the invariant, so it is called
  out as its own decision: **a user-supplied `workspace.celeryBrokerUrl`/`celeryResultBackend`
  must never be rewritten with an injected credential**, because the chart cannot know whether
  that URL already embeds its own credential, points at a different Redis than `cache`, or is
  intentionally credential-less.

- **Test-economy: land the full-chart test as a new suite file, not new `it:` cases inside
  `resources_test.yaml`, because `resources_test.yaml` currently has a pre-existing, unrelated
  failing test** (`configured extraction capture accounts render exactly` — asserts
  `data["config.yaml"]`, but `config-yaml.yaml` has rendered `stringData` since GX-17;
  `helm unittest -f 'tests/resources_test.yaml' src/groundx` on this branch's base commit fails
  with `unknown path data["config.yaml"]`, confirmed against a 1-commit-ahead-of-`0.2.7` checkout
  with no other local changes, so it predates this change and is not caused by it). Appending
  credential assertions to that file would make the new tests' pass/fail signal depend on an
  unrelated, already-broken assertion, defeating the RED-before/GREEN-after acceptance-check gate.
  A new suite file, `tests/redis-auth_test.yaml`, still satisfies Ben's "extend an existing test...
  values file" instruction literally — every case in it loads `../values/values.existing.yaml`,
  the same shared external-Redis values file the eight suites listed in the proposal already `-f`,
  so no new values fixture is introduced — only a new file for the new assertions themselves. This
  pre-existing failure is unrelated to GX-24 and is not fixed here (out of scope; flagged to the
  human at hand-off rather than silently patched, since fixing an unrelated test is scope creep on
  a `PRIVILEGED`-repo change).

- **Ranker's "own instance" (R1) branch is exercised via inline `set:` overrides in
  `tests/redis-auth_test.yaml`, not by adding a `ranker:` block to `values/values.existing.yaml`.**
  The proposal's `values/values.existing.yaml` edit is scoped to the `cache:` and `cache.metrics:`
  blocks only (matching the approved proposal's file/line list); adding an unrelated `ranker:`
  block to that shared file would be an undocumented expansion of an already-approved edit and
  risks perturbing the `inference_test.yaml` "existing" snapshot, which also loads this file for
  unrelated (GPU/replica) assertions. `helm-unittest`'s per-`it` `set:` overrides give the same
  coverage — ranker gets its own `cache.addr`/`password`/`username`, distinct from the main
  cache's — without touching the shared fixture beyond what the proposal describes.

## Risks / Trade-offs

- [Risk] A customer sets `cache.password` intending it for an *external* Redis (`cache.existing.addr`
  set) that does not actually have `requirepass`/ACL enabled → the AUTH call fails and the
  session/Celery clients cannot connect (a self-inflicted misconfiguration, not a defect in this
  render). → Mitigation: out of scope for this Helm-only change for an external instance, whose own
  auth config the customer owns; the client render is unconditional on whether the external target
  requires auth, matching the `db`/`search` precedent. For a *chart-created* (in-cluster) Redis this
  risk does not apply — the fourth decision in Amendments configures that server to require the same
  credential (see below).
- [Risk] Percent-encoding via `urlquery` uses Go's `url.QueryEscape`, which encodes a literal space
  as `+`, not `%20`; a password containing a space is round-tripped through kombu differently than
  through a strict userinfo percent-encoder. → Mitigation: out of scope for this chart change
  (`urlquery` is the mechanism named in the accepted contract/proposal); if this proves to be a
  real-world issue it is a follow-up on whichever repo's URL parser first surfaces it — no Linear
  ticket exists yet for this narrow edge case, so it is not recorded as a tracked deferral, only
  flagged here.
- [Risk] The R1 per-identity fallback means a chart-wide `cache.password` and a per-identity
  override (e.g. `ranker.cache.password`) can diverge silently if an operator sets one and forgets
  the other. → Mitigation: this mirrors the existing `addr` fallback's own failure mode (a
  mismatched `ranker.cache.addr` already causes ranker to point at the wrong Redis instance
  today), so it introduces no new class of misconfiguration risk beyond what `addr` already has.

## Migration Plan

- Deploy in any order; additive/default-off (see proposal.md Impact). No flag, no staged rollout,
  no coordinated release with cashbot-go/ai-server/internal-arcadia-agents/groundx-workspace-runner
  is required for the credential-less path — those repos' own changes only matter once an operator
  sets a credential.
- Rollback: `helm rollback` to the pre-change release; the config-hash annotation on each affected
  Deployment forces a rollout back to the prior rendered config on the next apply, matching every
  other config-file change in this chart (no new rollback mechanism needed).

## Amendments

- 2026-09-03: `groundx.metrics.cache.ssl` was corrected to resolve per-identity, mirroring
  `groundx.metrics.cache.addr`. It previously read the *main* cache's `cache.existing.ssl`, so a
  separately hosted TLS metrics Redis rendered `redis://` when the main cache was non-TLS — and once
  this change embeds credentials into that URL, that wrong scheme would send the credential over a
  plaintext connection (or fail the TLS handshake). It now reads `cache.metrics.existing.ssl` when
  metrics has its own external instance (chart-created metrics is non-TLS; a disabled metrics proxies
  to the main cache's scheme), completing R1's invariant that a rendered credential matches the exact
  instance — including its transport — it authenticates to. Default render is unchanged (default
  metrics is chart-created, so the scheme was and stays `redis://`).
- 2026-09-03: the space-encoding Risk note above ("Percent-encoding via `urlquery` ... a password
  containing a space is round-tripped through kombu differently than through a strict userinfo
  percent-encoder") is superseded — it is no longer deferred. All three userinfo helpers
  (`groundx.cache.userinfo`, `groundx.metrics.cache.userinfo`, `groundx.ranker.cache.userinfo`)
  post-process `urlquery`'s output with `replace "+" "%20"`, so a space in a password or username
  renders as the standard percent-encoded userinfo form (`%20`), never the literal `+`. Covered by
  the `redis-auth_test.yaml` case "a credential containing a space percent-encodes to %20 (never
  urlquery's literal '+'), for every identity", which asserts the `%20` form and asserts the
  literal-`+` form is absent, across the main cache, metrics cache, and the ranker's own instance.
- 2026-09-03: a fourth decision, orthogonal to the client-URL userinfo work above — the two
  chart-created Redis identities (main `cache` and `cache.metrics`; ranker/workspace are
  external-only and out of scope) are themselves configured to require the same credential their
  clients send, via a Secret-mounted `redis.conf`. The conf begins with `include /etc/redis.conf`
  (so the shipped image's own default config — `protected-mode no`, port, persistence — is
  preserved) and then adds the credential: `requirepass "<pw>"` for password-only, or
  `user default off` / `user <name> on ">pw" ~* &* +@all` for an ACL user; the credential is
  double-quoted and backslash/quote-escaped so a space or reserved character does not break startup.
  The StatefulSet mounts the Secret and sets `args: ["redis-server", "<mounted>/redis.conf"]`. The
  shipped image (`eyelevel/redis:1.0.0`, a UBI redis-6 whose `ENTRYPOINT ["container-entrypoint"]`
  is `exec "$@"` with `CMD ["redis-server", "/etc/redis.conf"]`) does not re-inject `redis-server`
  the way the stock `redis` image does, so the `redis-server` token must be explicit in `args` —
  passing only the conf path would make the container exec the config file and crash-loop. This was
  verified end-to-end against `eyelevel/redis:1.0.0` itself (not a stock redis): the chart-rendered
  conf + args start the server and a client authenticates, for password-only and ACL, including a
  space-containing password, and a wrong password is rejected. Default-off (no credential
  configured) renders no conf Secret, mount, or args, byte-identical to the prior render.
