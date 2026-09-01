As of 2026-09-01 (RED baseline, before implementation), every check below reproduced its own
failure on the then-unchanged code — verified live, every credentialed `helm template`/
`helm unittest` invocation failed with a schema-validation error: `additional properties
'password'/'username' not allowed`, which was the correct reason: the feature did not exist yet.
`helm` must be on `PATH` with the `unittest` plugin installed
(`helm plugin install https://github.com/helm-unittest/helm-unittest.git`). None of these checks
run `.build/bin/validate-helm.sh` or any other repo script.

**Snapshot-regen caution (discovered while authoring this change, see design.md D7 / Risks):** do
**not** run `helm unittest -u` for any reason in this change — even scoped to a single `-f` file,
the installed `helm-unittest` plugin (1.1.2) rewrites unrelated pre-existing snapshot entries
(verified live and reverted). None of the tasks below need `-u`; the new test files use
`matchRegex`/`failedTemplate`, never `matchSnapshot`, specifically to avoid this.

See the workspace-level `openspec/changes/gx-24-groundx-helm-chart-apps-support-authenticated-redis-auth/tasks.md`
(in the `engineering-context` meta-repo, not this service repo) for cross-service coordination — the
rollout-ordering constraint with the ai-server image — and any deferred items. This file carries only
groundx-on-prem's own implementation tasks.

## 1. Main `cache` identity — schema, render, guard (thin vertical slice)

- [x] 1.1 Declare `username`/`password` (string) on `cache` and `cache.existing` in
  `values.schema.json`, keeping `additionalProperties: false` on both.
  (Check line adds `cache.metrics.enabled=false`: a main-cache-only credential otherwise cascades
  into the F4 metrics-identity guard by design — see 2.4/design.md Amendments F4 — since the
  default-enabled metrics identity has no credential and no external address of its own, isolating
  this check to the main identity's own schema/render behavior.)
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.metrics.enabled=false --set cache.existing.addr=x.example.com --set cache.password=p --set cache.username=u --set cache.existing.password=ep --set cache.existing.username=eu >/dev/null'
- [x] 1.2 Add `groundx.cache.username` / `groundx.cache.password` (`_helpers/services/cache.tpl`):
  `coalesce(existing.<key>, top-level <key>)`. Render them as raw, unencoded `username:`/`password:`
  keys (omitted when empty) into `config-yaml.yaml`'s `rec.session` block, quoted per
  `groundx.redis.yamlScalar` (unconditional `| quote` — review round 1 finding F12).
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set cache.metrics.enabled=false --set cache.existing.addr=x.example.com --set cache.password=p --set cache.username=u --show-only templates/resources/config-yaml.yaml); grep -q "username: \"u\"" <<<"$o" && grep -q "password: \"p\"" <<<"$o"'
- [x] 1.3 Add `groundx.cache.userinfo` (empty when no password; else
  `printf "%s:%s@" (username|escaped) (password|escaped)`, where `escaped` is
  `groundx.redis.userinfoEscape` — `urlquery` followed by `replace "+" "%20"`, since `urlquery`
  alone (Go's `url.QueryEscape`) encodes a space as `+`, which a URL userinfo decoder
  (`urllib.parse.unquote`) leaves literal rather than turning back into a space (review round 1,
  finding F3). Use it to render percent-encoded userinfo into `layoutBroker`/`layoutResultBroker`
  (`layout-config-py.yaml`) and `summaryBroker`/`summaryResultBroker` (`summary-config-py.yaml`).
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set cache.metrics.enabled=false --set cache.existing.addr=x.example.com --set "cache.password=p@ss" --show-only templates/resources/layout-config-py.yaml); grep -q "redis://:p%40ss@x.example.com:6379/0" <<<"$o"'
- [x] 1.4 Add `groundx.cache.validateCredentials`, called once from `config-yaml.yaml`: `fail` with
  the exact message from design.md D4 when the resolved `cache` credential is non-empty and the
  identity's resolved address is not external (`groundx.cache.isExternal != "true"` — review
  round 1 finding F4: keying this on `groundx.cache.create` let `cache.enabled: false` with no
  `existing.addr` render a credential at the chart's own bundled DNS silently, since `create`
  followed the `enabled` flag rather than the actual resolved address). Also `fail` when a
  username is set with no password on an otherwise-external cache — a username with no password
  (nopass ACL) is rejected, per decision (a) (finding F5).
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.password=p 2>&1 | grep -qF "cache.password/cache.username require an external Redis (cache.existing.addr); the chart'"'"'s own bundled Redis has no AUTH support"'
- [x] 1.5 Main-cache identity slice is complete: every case in the authored test file passes
  (raw render, percent-encoding, precedence, fail-loud, must-not-block, byte-identical default,
  nopass rejection, bundled-DNS-when-disabled rejection, %20 space-in-userinfo encoding).
  check: helm unittest src/groundx -f 'tests/cache_credentials_test.yaml'
- [x] 1.6 Round-trip check (review round 1 finding F6): the rendered userinfo, decoded with a real
  URL decoder (`urllib.parse.urlsplit` + `unquote`), equals the configured username/password,
  including a space character — proving F3's `%20` fix and a real consumer's decoder agree, not
  just this chart's own regex assertions.
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set cache.metrics.enabled=false --set cache.existing.addr=x.example.com --set "cache.password=my pass" --set "cache.username=my user" --show-only templates/resources/layout-config-py.yaml); url=$(echo "$o" | grep -oE "layoutBroker=\"redis://[^\"]+\"" | sed -E "s/^layoutBroker=\"//; s/\"\$//"); python3 -c "
import sys
from urllib.parse import urlsplit, unquote
u = urlsplit(sys.argv[1])
pw = unquote(u.password or \"\")
un = unquote(u.username or \"\")
assert pw == \"my pass\" and un == \"my user\", (un, pw)
" "$url"'

## 2. `cache.metrics` identity — inherits the main cache credential by default (widen)

- [x] 2.1 Declare `username`/`password` on `cache.metrics` and `cache.metrics.existing` in
  `values.schema.json`, keeping `additionalProperties: false` on both.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.metrics.password=p --set cache.metrics.existing.addr=m.example.com --set cache.metrics.existing.password=ep >/dev/null'
- [x] 2.2 Add `groundx.metrics.cache.username` / `.password`. The main-cache fallback
  (`groundx.cache.<key>`) applies **only when metrics has no `existing.addr` of its own** — the
  same predicate `groundx.metrics.cache.addr` already uses to decide whether metrics inherits the
  main address. Review round 1 finding F1: the original `coalesce(existing.<key>, metrics.<key>,
  groundx.cache.<key>)` fell back to the main credential unconditionally, so an identity with its
  own external `existing.addr` but no own credential would render the main cache's credential
  against a *different host* — `values.existing.yaml`'s own configuration triggers this (two
  distinct external Redis addresses, one credential). When metrics has its own `existing.addr`,
  the resolved credential is `coalesce(existing.<key>, metrics.<key>)` with **no** main fallback —
  an identity pointed at its own external Redis with no credential of its own renders no
  credential, not someone else's. Render raw into `config-yaml.yaml`'s `metrics.session` block,
  quoted per `groundx.redis.yamlScalar` (unconditional `| quote` — review round 1 finding F12).
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set cache.metrics.existing.addr=m.example.com --set cache.metrics.existing.password=mp --set cache.metrics.existing.username=mu --show-only templates/resources/config-yaml.yaml); grep -q "username: \"mu\"" <<<"$o" && grep -q "password: \"mp\"" <<<"$o"'
- [x] 2.3 Add `groundx.metrics.cache.userinfo` (same shape as 1.3, including the F3 `%20`
  userinfo-safe escaping) and use it for every `metricsBroker` URL (`layout-config-py.yaml`,
  `ranker-config-py.yaml`, `summary-config-py.yaml`).
  check: bash -c 'for t in layout ranker summary; do o=$(helm template gx src/groundx -n eyelevel --set cache.metrics.existing.addr=m.example.com --set cache.metrics.existing.password=mp --show-only templates/resources/$t-config-py.yaml) || exit 1; grep -q "metricsBroker=\"redis://:mp@m.example.com:6379/0\"" <<<"$o" || exit 1; done'
- [x] 2.4 Add the metrics-identity fail-loud check to `groundx.cache.validateCredentials`: `fail`
  with the design.md D4 message when the resolved metrics credential is non-empty and the
  identity's resolved address is not external (`groundx.metrics.cache.isExternal != "true"`).
  Review round 1 finding F4: keying this on `groundx.metrics.cache.create` was wrong whenever
  metrics had no `existing.addr` of its own — `create` delegated to the *main* cache's
  create/external state, so an external main cache with a bundled (default-enabled) metrics
  identity made this guard resolve `false` and silently render the metrics credential at the
  metrics identity's own bundled pod (`cache-metrics.<ns>`), which has no AUTH support. The fix
  checks the metrics identity's own resolved externality, independent of the main identity's.
  Also `fail` when a username is set with no password on an otherwise-external metrics identity
  (nopass ACL rejection, finding F5).
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.metrics.password=p 2>&1 | grep -qF "cache.metrics.password/cache.metrics.username require an external Redis"'
- [x] 2.5 Metrics-identity slice is complete: every case in the authored test file passes
  (inheritance, own-value override, fail-loud (including the two F4 bundled-vs-external edge
  cases), must-not-block, nopass rejection, byte-identical default, and the F1
  own-external-addr-no-own-credential case renders no credential).
  check: helm unittest src/groundx -f 'tests/cache_metrics_credentials_test.yaml'

## 3. `ranker.cache` identity — inherits the main cache credential by default (widen)

- [x] 3.1 Declare `username`/`password` on `ranker.cache` (flat, no `existing` sub-object) in
  `values.schema.json`, keeping `additionalProperties: false`.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set ranker.cache.addr=r.example.com --set ranker.cache.password=p --set ranker.cache.username=u >/dev/null'
- [x] 3.2 Add `groundx.ranker.cache.create` (`false` when `groundx.ranker.cache.existing == "true"`,
  else delegates to `groundx.cache.create` — see design.md D3) and `groundx.ranker.cache.isExternal`
  (`true` when `groundx.ranker.cache.existing == "true"`, else delegates to
  `groundx.cache.isExternal` — used by validateCredentials, see 3.3). `groundx.ranker.cache.username`/
  `.password` resolve `coalesce(ranker.cache.<key>, groundx.cache.<key>)` **only when
  `groundx.ranker.cache.existing == "false"`** — when ranker has its own `addr`, its own credential
  is used with no main-cache fallback (review round 1 finding F1, same predicate-gating fix as
  2.2 — ranker's own `addr` and no own credential must render no credential, not the main cache's).
  `groundx.ranker.cache.userinfo` uses the same shape as 1.3, including the F3 `%20`
  userinfo-safe escaping. Use `userinfo` to render percent-encoded credentials into
  `searchBroker`/`searchResultBroker` (`ranker-config-py.yaml`).
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set ranker.cache.addr=r.example.com --set ranker.cache.password=p --show-only templates/resources/ranker-config-py.yaml); grep -q "searchBroker=\"redis://:p@r.example.com:6379/0\"" <<<"$o"'
- [x] 3.3 Add the ranker-identity fail-loud check to `groundx.cache.validateCredentials`: `fail`
  with the design.md D4 message when the resolved ranker credential is non-empty and
  `groundx.ranker.cache.isExternal != "true"` (review round 1 finding F4 — keyed on the identity's
  resolved externality, not `*.create`, for the same reason as 1.4/2.4). Also `fail` when a
  username is set with no password on an otherwise-external ranker identity (nopass ACL
  rejection, finding F5). This is also what proves `groundx.ranker.cache.create`/`.isExternal`
  from 3.2 resolve correctly — a wrong value fails this check either by never firing (guard
  silently missed) or firing for the legitimate external-ranker case in 3.4's test file.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set ranker.cache.password=p 2>&1 | grep -qF "ranker.cache.password/ranker.cache.username require an external Redis"'
- [x] 3.4 Ranker-identity slice is complete: every case in the authored test file passes
  (inheritance, own-value override, fail-loud, must-not-block, nopass rejection, byte-identical
  default, and the F1 own-external-addr-no-own-credential case renders no credential).
  check: helm unittest src/groundx -f 'tests/ranker_cache_credentials_test.yaml'

## 4. Mirror sync, documentation, and cross-cutting validation

- [x] 4.1 Apply the identical delta (schema, helpers, template renders, guard) to the `helm/`
  manual mirror. Do not touch `helm/`'s pre-existing, unrelated drift (Chart.yaml version, one
  memory value) — this task is scoped to the credential delta only.
  check: bash -c 'f=$(find openspec/changes -iname "verify-mirror-parity.sh" -path "*gx-24-groundx-helm-chart-apps-support-authenticated-redis-auth*" | head -1); test -n "$f" && bash "$f"'
  (review round 1 finding F7: the check line above previously hardcoded the pre-archive path
  `openspec/changes/gx-24-.../verify-mirror-parity.sh`, which no longer exists once this change
  folder is archived under a dated `openspec/changes/archive/<date>-gx-24-.../` prefix — that made
  the check exit 127 (command not found) rather than run. The glob above locates the script by
  name under either an active or archived change folder, so the check stays runnable regardless of
  archival state.)
- [x] 4.2 Document the new keys in `values.yaml` as commented-out examples on `cache`,
  `cache.existing`, `cache.metrics`, `cache.metrics.existing`, and `ranker.cache` (matching the
  existing commented-example style already used for `db`/`file`/`cache.existing`).
  check: n/a — comment-only documentation, no rendered behavior change
- [x] 4.3 Document the new keys in `values/values.existing.yaml` as commented-out examples only
  (see design.md D7 — not live values, to avoid any snapshot regeneration in this environment).
  check: n/a — comment-only documentation, no rendered behavior change
- [x] 4.4 All three GX-24 credentialed-render test files pass together, and both chart surfaces
  still lint clean (final cross-identity acceptance, one command — `helm lint` alone already
  passes pre-implementation, which is why it rides on this check rather than standing alone as a
  task the RED baseline could never fail).
  check: bash -c "helm unittest src/groundx -f 'tests/cache_credentials_test.yaml' -f 'tests/cache_metrics_credentials_test.yaml' -f 'tests/ranker_cache_credentials_test.yaml' && helm lint src/groundx && helm lint helm"
- [x] 4.5 Both chart surfaces fail identically on the bundled-credential render, not only agree on
  a successful render (review round 1 finding F10 — `verify-mirror-parity.sh` previously only
  compared successful renders; a mismatch on the failure path, e.g. one surface's guard message
  drifting from the other's, would have gone undetected). Added as
  `check_both_fail_identically` in `verify-mirror-parity.sh`, exercising `spec.md`'s "both mirrors
  fail identically on the bundled-cache case" scenario.
  check: bash -c 'f=$(find openspec/changes -iname "verify-mirror-parity.sh" -path "*gx-24-groundx-helm-chart-apps-support-authenticated-redis-auth*" | head -1); test -n "$f" && bash "$f"'

`extract-config-py.yaml` / `workspace-config-py.yaml` remain explicitly out of scope for GX-24 (see
proposal.md "Explicitly out of scope" and design.md Non-Goals) — a deferred follow-up, not part of
this change, per the plan-gate resolution; a follow-up ticket is to be filed at hand-off. The
`helm-unittest` plugin's snapshot-rewrite behavior
(design.md D7 / Risks) is a pre-existing environment finding this change works around, not a GX-24
follow-up; it is reported to the orchestrator rather than recorded here as a ticket-less deferral.
