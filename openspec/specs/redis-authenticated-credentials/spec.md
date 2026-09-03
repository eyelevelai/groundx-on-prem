# redis-authenticated-credentials Specification

## Purpose
TBD - created by archiving change gx-24-authenticated-redis-all-consumers. Update Purpose after archive.
## Requirements
### Requirement: Cashbot-go's Secret-backed session config carries the main and metrics cache credentials

SHALL render `username`/`password` fields on the `rec.session` block (main `cache` identity) and, independently, on the `metrics.session` block (`cache.metrics` identity) of `templates/resources/config-yaml.yaml` (and its manual mirror `helm/templates/resources/config-yaml.yaml`) whenever that identity's resolved `username`/`password` is non-empty, guarded exactly as the existing `db.username`/`db.password` fields already are (`{{- if ne (...) "" }}`), and SHALL omit the field entirely when empty.

#### Scenario: Main cache credential renders on rec.session (polarity: finalize success)

- **GIVEN** `cache.password` is set to a non-empty value and `cache.username` is set
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`
- **THEN** the rendered `stringData["config.yaml"]`'s `rec.session` block contains `username` and
  `password` fields equal to the configured values (not percent-encoded — this is a plain YAML
  field, not a URL)
- **AND THEN** `metrics.session` does not gain a credential it was never configured with (the
  per-identity guard fires independently)

#### Scenario: No credential set omits both fields (polarity: reject before state — nothing is added)

- **GIVEN** `cache.password` and `cache.username` are unset (the 0.2.7 default)
- **WHEN** `helm template` renders `templates/resources/config-yaml.yaml`
- **THEN** neither `rec.session` nor `metrics.session` contains a `username` or `password` key,
  and the rest of the rendered `config.yaml` is byte-identical to 0.2.7 (the opposite outcome — a
  stray empty `password: ""` line, or any other diff — must not occur)

### Requirement: Every Celery broker/result URL carries its own identity's credential, percent-encoded

SHALL embed `[username:]password@` into every broker/result-backend URL that `templates/resources/{layout,summary,extract,ranker}-config-py.yaml` and `templates/_helpers/app/workspace.tpl`'s `celeryBrokerUrl`/`celeryResultBackend` helpers (and their `helm/` mirrors) build from a cache identity's `scheme`/`addr`/`port`, using that call site's **own** identity (main `cache`, `cache.metrics`, or `ranker.cache`) — never a different identity's credential — with the username and password percent-encoded (Sprig `urlquery`) so a URL-reserved character survives.

#### Scenario: Layout/summary/extract broker URLs embed the main and metrics credentials (polarity: finalize success)

- **GIVEN** `cache.password="cache-p@ss:w0rd"`, `cache.username="cache-acl-user"`, and
  `cache.metrics.password="metrics-p@ss:w0rd"` (no metrics username — the password-only AUTH case)
- **WHEN** `helm template` renders `layout-config-py.yaml`, `summary-config-py.yaml`, and
  `extract-config-py.yaml`
- **THEN** every URL built from the main `cache` identity (`layoutBroker`, `layoutResultBroker`,
  `summaryBroker`, `summaryResultBroker`, `broker`) contains the literal encoded fragment
  `cache-acl-user:cache-p%40ss%3Aw0rd@` immediately after `scheme://`
- **AND THEN** every URL built from the `cache.metrics` identity (`metricsBroker` in all three
  files) contains `metrics-p%40ss%3Aw0rd@` immediately after `scheme://`, with no `username:`
  prefix (metrics has no username configured)

#### Scenario: Ranker's own instance gets its own credential, never the main cache's (polarity: finalize success — catches the mechanical-sweep counterexample)

- **GIVEN** `ranker.cache.addr`, `ranker.cache.password`, and `ranker.cache.username` are set to
  values distinct from the main `cache` identity's own (separately configured) credential
- **WHEN** `helm template` renders `ranker-config-py.yaml`
- **THEN** `searchBroker` and `searchResultBroker` contain ranker's own encoded `username:password@`
  fragment
- **AND THEN** neither `searchBroker` nor `searchResultBroker` contains the main cache's
  credential anywhere in the rendered document (the counterexample a copy-pasted
  `groundx.cache.userinfo` — instead of `groundx.ranker.cache.userinfo` — at this call site would
  produce: the mechanical `printf` shape would still be satisfied, but the wrong Redis instance
  would receive the credential)

#### Scenario: Ranker with no own instance inherits the main cache's credential (polarity: finalize success — must-not-block case)

- **GIVEN** `ranker.cache` has no `addr` set (ranker shares the main cache, the 0.2.7 default
  topology) and `cache.password`/`cache.username` are set
- **WHEN** `helm template` renders `ranker-config-py.yaml`
- **THEN** `searchBroker` and `searchResultBroker` **do** contain the main cache's encoded
  credential (this is correct — ranker is authenticating to the same Redis instance the main
  cache identity points at, so inheriting its credential is required, not a leak) — a gate that
  rejected this case as "wrong instance" would incorrectly block ranker's legitimate default
  topology

### Requirement: Per-identity credential fallback mirrors that identity's existing address fallback (R1)

`groundx.metrics.cache.password`/`username` SHALL fall back to the main `cache` identity's
credential exactly when `groundx.metrics.cache.addr` would (i.e. `cache.metrics.enabled` is not
`true`), and `groundx.ranker.cache.password`/`username` SHALL fall back to the main `cache`
identity's credential exactly when `groundx.ranker.cache.addr` would (i.e. `ranker.cache.addr` is
unset) — so a rendered credential always matches the Redis instance its sibling `addr`/`scheme`/
`port` helpers already resolve to for that same identity.

#### Scenario: Metrics with its own instance does not inherit the main cache's credential (polarity: finalize success)

- **GIVEN** `cache.metrics.enabled=true`, `cache.metrics.existing.addr` set to a distinct host, and
  `cache.metrics.password` set to a value different from `cache.password`
- **WHEN** `helm template` renders any file embedding `groundx.metrics.cache.userinfo` or the
  `config-yaml.yaml` `metrics.session` block
- **THEN** the rendered credential is `cache.metrics.password`'s value, never `cache.password`'s

### Requirement: A user-supplied workspace Celery URL is never rewritten with an injected credential (R2)

`groundx.workspace.celeryBrokerUrl` and `groundx.workspace.celeryResultBackend` SHALL inject the
main cache identity's credential only into the chart-built fallback URL (the branch used when
`workspace.celeryBrokerUrl`/`celeryResultBackend` is unset); a value the operator sets explicitly
SHALL pass through unmodified.

#### Scenario: Fallback URL carries the main cache credential (polarity: finalize success)

- **GIVEN** `workspace.celeryBrokerUrl` and `workspace.celeryResultBackend` are unset, and
  `cache.password`/`cache.username` are set
- **WHEN** `helm template` renders `workspace-config-py.yaml`
- **THEN** `celery_broker_url` and `celery_result_backend` both contain the main cache's encoded
  `username:password@` fragment

#### Scenario: An operator-supplied full URL is never rewritten (polarity: skip unrelated repair path)

- **GIVEN** `workspace.celeryBrokerUrl="rediss://custom-op:custom-secret@other-redis.mycorp.net:6379/2"`
  is set explicitly, and `cache.password`/`cache.username` are also set (a different credential)
- **WHEN** `helm template` renders `workspace-config-py.yaml`
- **THEN** `celery_broker_url` is exactly the operator-supplied string, unmodified — it does **not**
  contain the main cache's credential, and the chart does not attempt to merge, replace, or
  append to the operator's own userinfo (the opposite outcome — the chart "helpfully" injecting or
  overwriting credentials into a URL it did not build — must not occur)

### Requirement: With no credential configured, every affected render stays byte-identical to 0.2.7 (backward compatibility)

SHALL render output identical to the chart's pre-GX-24 (0.2.7) output, in both `src/groundx/` and `helm/`, for every template this change touches (`config-yaml.yaml`, `{layout,summary,extract,ranker,workspace}-config-py.yaml`), when `cache.password`, `cache.username`, `cache.metrics.password`, `cache.metrics.username`, `ranker.cache.password`, and `ranker.cache.username` are all unset (the default) — so an existing on-prem install that has not opted in is unaffected by this change during and after rollout.

#### Scenario: Existing default and `values.yaml`-driven installs are unaffected (polarity: reject before state — no new state, no new render, no new field)

- **GIVEN** any values file that does not set a cache/metrics/ranker credential (including the
  chart's own `values.yaml` defaults and every pre-existing `helm-unittest` values fixture)
- **WHEN** `helm template` renders the chart, in either `src/groundx/` or `helm/`
- **THEN** the rendered output for every affected template is unchanged from 0.2.7 — proven by the
  pre-existing `helm-unittest` golden snapshots (`cache_test.yaml`, `resources_test.yaml`,
  `golang_test.yaml`, `metrics_test.yaml`, `celery_test.yaml`, `inference_test.yaml`,
  `stream_test.yaml`, `api_test.yaml`) continuing to match without regeneration

