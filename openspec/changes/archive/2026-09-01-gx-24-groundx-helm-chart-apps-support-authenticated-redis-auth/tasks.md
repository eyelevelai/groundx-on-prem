Every check below is runnable and reproduces its own failure on unchanged code (verified live —
today every credentialed `helm template`/`helm unittest` invocation fails with a schema-validation
error: `additional properties 'password'/'username' not allowed`, which is the correct reason: the
feature does not exist yet). `helm` must be on `PATH` with the `unittest` plugin installed
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
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.existing.addr=x.example.com --set cache.password=p --set cache.username=u --set cache.existing.password=ep --set cache.existing.username=eu >/dev/null'
- [x] 1.2 Add `groundx.cache.username` / `groundx.cache.password` (`_helpers/services/cache.tpl`):
  `coalesce(existing.<key>, top-level <key>)`. Render them as raw, unencoded `username:`/`password:`
  keys (omitted when empty) into `config-yaml.yaml`'s `rec.session` block.
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set cache.existing.addr=x.example.com --set cache.password=p --set cache.username=u --show-only templates/resources/config-yaml.yaml); grep -q "username: u" <<<"$o" && grep -q "password: p" <<<"$o"'
- [x] 1.3 Add `groundx.cache.userinfo` (empty when no password; else
  `printf "%s:%s@" (username|urlquery) (password|urlquery)`). Use it to render percent-encoded
  userinfo into `layoutBroker`/`layoutResultBroker` (`layout-config-py.yaml`) and
  `summaryBroker`/`summaryResultBroker` (`summary-config-py.yaml`).
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set cache.existing.addr=x.example.com --set "cache.password=p@ss" --show-only templates/resources/layout-config-py.yaml); grep -q "redis://:p%40ss@x.example.com:6379/0" <<<"$o"'
- [x] 1.4 Add `groundx.cache.validateCredentials`, called once from `config-yaml.yaml`: `fail` with
  the exact message from design.md D4 when the resolved `cache` credential is non-empty and
  `groundx.cache.create == "true"`.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.password=p 2>&1 | grep -qF "cache.password/cache.username require an external Redis (cache.existing.addr); the chart'"'"'s own bundled Redis has no AUTH support"'
- [x] 1.5 Main-cache identity slice is complete: every case in the authored test file passes
  (raw render, percent-encoding, precedence, fail-loud, must-not-block, byte-identical default).
  check: helm unittest src/groundx -f 'tests/cache_credentials_test.yaml'

## 2. `cache.metrics` identity — inherits the main cache credential by default (widen)

- [x] 2.1 Declare `username`/`password` on `cache.metrics` and `cache.metrics.existing` in
  `values.schema.json`, keeping `additionalProperties: false` on both.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.metrics.password=p --set cache.metrics.existing.addr=m.example.com --set cache.metrics.existing.password=ep >/dev/null'
- [x] 2.2 Add `groundx.metrics.cache.username` / `.password`:
  `coalesce(metrics.existing.<key>, metrics.<key>, groundx.cache.<key>)`. Render raw into
  `config-yaml.yaml`'s `metrics.session` block.
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set cache.metrics.existing.addr=m.example.com --set cache.metrics.existing.password=mp --set cache.metrics.existing.username=mu --show-only templates/resources/config-yaml.yaml); grep -q "username: mu" <<<"$o" && grep -q "password: mp" <<<"$o"'
- [x] 2.3 Add `groundx.metrics.cache.userinfo` (same shape as 1.3) and use it for every
  `metricsBroker` URL (`layout-config-py.yaml`, `ranker-config-py.yaml`, `summary-config-py.yaml`).
  check: bash -c 'for t in layout ranker summary; do o=$(helm template gx src/groundx -n eyelevel --set cache.metrics.existing.addr=m.example.com --set cache.metrics.existing.password=mp --show-only templates/resources/$t-config-py.yaml) || exit 1; grep -q "metricsBroker=\"redis://:mp@m.example.com:6379/0\"" <<<"$o" || exit 1; done'
- [x] 2.4 Add the metrics-identity fail-loud check to `groundx.cache.validateCredentials`: `fail`
  with the design.md D4 message when the resolved metrics credential is non-empty and
  `groundx.metrics.cache.create == "true"`.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set cache.metrics.password=p 2>&1 | grep -qF "cache.metrics.password/cache.metrics.username require an external Redis"'
- [x] 2.5 Metrics-identity slice is complete: every case in the authored test file passes
  (inheritance, own-value override, fail-loud, must-not-block, byte-identical default).
  check: helm unittest src/groundx -f 'tests/cache_metrics_credentials_test.yaml'

## 3. `ranker.cache` identity — inherits the main cache credential by default (widen)

- [x] 3.1 Declare `username`/`password` on `ranker.cache` (flat, no `existing` sub-object) in
  `values.schema.json`, keeping `additionalProperties: false`.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set ranker.cache.addr=r.example.com --set ranker.cache.password=p --set ranker.cache.username=u >/dev/null'
- [x] 3.2 Add `groundx.ranker.cache.create` (`false` when `groundx.ranker.cache.existing == "true"`,
  else delegates to `groundx.cache.create` — see design.md D3), `groundx.ranker.cache.username`/
  `.password` (`coalesce(ranker.cache.<key>, groundx.cache.<key>)`), and `groundx.ranker.cache.userinfo`
  (same shape as 1.3). Use `userinfo` to render percent-encoded credentials into
  `searchBroker`/`searchResultBroker` (`ranker-config-py.yaml`).
  check: bash -c 'o=$(helm template gx src/groundx -n eyelevel --set ranker.cache.addr=r.example.com --set ranker.cache.password=p --show-only templates/resources/ranker-config-py.yaml); grep -q "searchBroker=\"redis://:p@r.example.com:6379/0\"" <<<"$o"'
- [x] 3.3 Add the ranker-identity fail-loud check to `groundx.cache.validateCredentials`: `fail`
  with the design.md D4 message when the resolved ranker credential is non-empty and
  `groundx.ranker.cache.create == "true"`. This is also what proves `groundx.ranker.cache.create`
  from 3.2 resolves correctly — a wrong `create` value fails this check either by never firing
  (guard silently missed) or firing for the legitimate external-ranker case in 3.4's test file.
  check: bash -c 'helm template gx src/groundx -n eyelevel --set ranker.cache.password=p 2>&1 | grep -qF "ranker.cache.password/ranker.cache.username require an external Redis"'
- [x] 3.4 Ranker-identity slice is complete: every case in the authored test file passes
  (inheritance, own-value override, fail-loud, must-not-block, byte-identical default).
  check: helm unittest src/groundx -f 'tests/ranker_cache_credentials_test.yaml'

## 4. Mirror sync, documentation, and cross-cutting validation

- [x] 4.1 Apply the identical delta (schema, helpers, template renders, guard) to the `helm/`
  manual mirror. Do not touch `helm/`'s pre-existing, unrelated drift (Chart.yaml version, one
  memory value) — this task is scoped to the credential delta only.
  check: bash openspec/changes/gx-24-groundx-helm-chart-apps-support-authenticated-redis-auth/verify-mirror-parity.sh
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

`extract-config-py.yaml` / `workspace-config-py.yaml` are explicitly out of scope for GX-24 (see
proposal.md "Explicitly out of scope" and design.md Non-Goals) — not a deferred task, a permanent
scope boundary from the plan-gate resolution. The `helm-unittest` plugin's snapshot-rewrite behavior
(design.md D7 / Risks) is a pre-existing environment finding this change works around, not a GX-24
follow-up; it is reported to the orchestrator rather than recorded here as a ticket-less deferral.
