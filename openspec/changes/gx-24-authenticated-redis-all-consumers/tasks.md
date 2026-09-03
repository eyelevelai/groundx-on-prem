## 1. Main cache identity end-to-end (cashbot-go's shared session client)

- [ ] 1.1 Add `groundx.cache.password`/`groundx.cache.username` helpers to
  `templates/_helpers/services/cache.tpl` (both `src/groundx/` and `helm/`), mirroring
  `groundx.db.password` exactly (`dig "password"/"username" "" .Values.cache`, no `existing`
  indirection). Render guarded `username`/`password` fields into `config-yaml.yaml`'s `rec.session`
  block (both mirrors), placed after `ssl`, each behind its own `{{- if ne (...) "" }}` guard
  mirroring the existing `db.username`/`db.password` guard in the same file. Add `password`/
  `username` string properties (default `""`) to the `cache` block in `values.schema.json` (both
  mirrors — currently `additionalProperties: false`). Add one concise one-line comment plus the two
  `password`/`username` keys (empty string) to `cache:` in `values.yaml` (both mirrors). Set
  `cache.password`/`cache.username` on the `cache:` block of `values/values.existing.yaml` (both
  mirrors) to the ACL user+password fixture values `redis-auth_test.yaml` already asserts on
  (`cache-acl-user` / `cache-p@ss:w0rd`).
  check: helm unittest -f 'tests/redis-auth_test.yaml' src/groundx

## 2. Metrics identity (R1 fallback, same consumer)

- [ ] 2.1 Add `groundx.metrics.cache.password`/`username` helpers to `cache.tpl` (both mirrors):
  own value from `.Values.cache.metrics` when `cache.metrics.enabled` is `true` (the same
  condition `groundx.metrics.cache.addr` already branches on), else `include
  "groundx.cache.password"`/`"groundx.cache.username"`. Render the same guarded fields into
  `config-yaml.yaml`'s `metrics.session` block (both mirrors), after `ssl`. Add `password`/
  `username` properties to `cache.metrics` in `values.schema.json` (both mirrors). Add the two keys
  (with a one-line comment) to `cache.metrics:` in `values.yaml` (both mirrors). Set
  `cache.metrics.password` (password-only case, no username) on `values/values.existing.yaml`'s
  `cache.metrics:` block (both mirrors) to `metrics-p@ss:w0rd`.
  check: helm unittest -f 'tests/redis-auth_test.yaml' src/groundx

## 3. URL-embedded consumers: layout, summary, extract (main + metrics identity)

- [ ] 3.1 Add `groundx.cache.userinfo` and `groundx.metrics.cache.userinfo` helpers to `cache.tpl`
  (both mirrors): return `""` when no password is set, `"<urlquery(password)>@"` when only a
  password is set, and `"<urlquery(username)>:<urlquery(password)>@"` when both are set (Sprig
  `urlquery` for percent-encoding). Update every `printf "%s://%s:%v/0" scheme addr port` call site
  in `layout-config-py.yaml`, `summary-config-py.yaml`, and `extract-config-py.yaml` (both mirrors)
  to `printf "%s://%s%s:%v/0" scheme userinfo addr port`, using each call site's own identity
  (`groundx.cache.userinfo` for the main-cache-derived URLs, `groundx.metrics.cache.userinfo` for
  every `metricsBroker`/`metrics_broker`) — never a different identity's helper at that call site
  (see design.md's invariant).
  check: helm unittest -f 'tests/redis-auth_test.yaml' src/groundx

## 4. Ranker identity (R1 own-instance fallback)

- [ ] 4.1 Add `groundx.ranker.cache.password`/`username`/`userinfo` helpers to
  `templates/_helpers/app/ranker.tpl` (both mirrors): own value from `.Values.ranker.cache` when
  `groundx.ranker.cache.existing` is `"true"` (the same gate `groundx.ranker.cache.addr` already
  uses), else `include "groundx.cache.password"`/`"groundx.cache.username"`; `userinfo` follows the
  same `urlquery`-encoded shape as the main/metrics identities. Update `searchBroker` and
  `searchResultBroker` in `ranker-config-py.yaml` (both mirrors) to embed
  `groundx.ranker.cache.userinfo` (never `groundx.cache.userinfo` — this is the call site the
  mechanical-sweep counterexample in design.md/spec.md is about); leave `metricsBroker` there
  embedding `groundx.metrics.cache.userinfo` (added in task 3.1). Add `password`/`username`
  properties to `ranker.cache` in `values.schema.json` (both mirrors). Add two commented one-line
  examples (`# password: ...`, `# username: ...`) to the existing commented `ranker.cache: {}`
  block in `values.yaml` (both mirrors), matching its existing `# addr:`/`# isCluster:`/etc. style
  — no new active default value (ranker has no own instance by default).
  check: helm unittest -f 'tests/redis-auth_test.yaml' src/groundx

## 5. Workspace identity (R2 — fallback-only injection)

- [ ] 5.1 Update `groundx.workspace.celeryBrokerUrl` and `groundx.workspace.celeryResultBackend` in
  `templates/_helpers/app/workspace.tpl` (both mirrors): embed `groundx.cache.userinfo` into the
  `$fallback` URL's `printf` only; the `coalesce (dig "celeryBrokerUrl"/"celeryResultBackend" "" $in)
  $fallback` line itself is unchanged, so a value the operator sets explicitly is never rewritten.
  check: helm unittest -f 'tests/redis-auth_test.yaml' src/groundx

## 6. Cross-cutting gates

- [ ] 6.1 Confirm `helm lint src/groundx` and `helm lint helm` both stay clean after the
  `values.schema.json`/`values.yaml` edits above.
  check: n/a — non-behavioral lint gate; no new lint rule is added, this is a pass/fail-only
  smoke that is not expected to change state (see design.md test-economy note)
- [ ] 6.2 Confirm both chart mirrors render the credentialed `values/values.existing.yaml` fixture
  identically (the full-chart, both-mirrors-identical proof design.md commits to), spot-checked on
  `config-yaml.yaml` (plain-field shape) and `workspace-config-py.yaml` (URL-embedded shape) as the
  two representative credential-delivery shapes — the shared `_helpers/*.tpl` mirroring already
  makes the other four templates structurally identical once these two prove out.
  check: bash -c 'set -e -o pipefail; a="$(helm template t src/groundx -f src/groundx/values/values.existing.yaml --set workspace.enabled=true --set workspace.token=test-runner-token --show-only templates/resources/config-yaml.yaml --show-only templates/resources/workspace-config-py.yaml | grep -v -E "^ *(appVersion|chart|version):")"; b="$(helm template t helm -f helm/values/values.existing.yaml --set workspace.enabled=true --set workspace.token=test-runner-token --show-only templates/resources/config-yaml.yaml --show-only templates/resources/workspace-config-py.yaml | grep -v -E "^ *(appVersion|chart|version):")"; [ "$a" = "$b" ]; grep -q "cache-acl-user:cache-p%40ss%3Aw0rd@cache.existing.com" <<< "$a"'

Cross-service coordination (cashbot-go's `Username` field, ai-server's `status.py` credential
parse, the internal-arcadia-agents/groundx-workspace-runner broker-URL spikes, and the rollout
ordering across all of them) is tracked in the workspace-level
`openspec/changes/gx-24-authenticated-redis-all-consumers/tasks.md`, not here — this repo's tasks
are chart-render-only. This change is purely additive (new optional keys, new guarded render
branches); there is no existing shape being contracted or removed, so no expand/contract follow-up
item is needed.
