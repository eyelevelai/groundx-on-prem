# GX-24: Render authenticated-Redis credentials for every cache-consuming workload

- **Ticket**: GX-24
- **Author**: Nitin Vavdiya <nitin.vavdiya@smartsensesolutions.com>
- **Date**: 2026-09-03

## Why

Chart 0.2.7 renders no Redis auth anywhere: every cache config block emits only
`addr`/`notCluster`/`ssl`, and every Celery broker/result URL renders `scheme://addr:port/0`
with no credential. A customer pointing GroundX at their own authenticated or managed Redis
(ElastiCache AUTH token/RBAC user, Azure access key, Memorystore AUTH string, or an on-prem
`requirepass` instance) cannot connect — the dependent workloads receive host/port/TLS but never
a password, so an authenticated Redis returns `NOAUTH` and they fail to start. This blocks
"bring your own hardened Redis" as a supported on-prem path, and it is the functional complement
to GX-17 (which moved these workloads' existing credentials out of plaintext ConfigMaps into
Secrets — this ticket lets GroundX *consume* a credential the customer's Redis requires).

Per CTO comment 756aee1c (2026-09-02, authoritative — supersedes this ticket's original
Scope/Out-of-scope and its bespoke inline mechanism), the chart's job spans **every** independently
addressable cache identity in the chart, not just cashbot-go's shared session cache: the main
cache, the metrics cache, ranker's cache, and workspace's Celery broker/result URL. It also
corrects the credential-delivery mechanism to reuse the paradigm GX-17 already established and
Ben already accepted — render the credential inline into the config files that are already
`kind: Secret` — rather than the env-injection / `envFrom` / `secretRef` / `existingSecret` shapes
Ben rejected in GX-17 (on-prem#77, cashbot-go#1673, ai-server#53, closed as "a massive potentially
breaking change").

## What Changes

- Add two plain, optional, top-level values on the main cache block — `cache.password` and
  `cache.username` — via new `groundx.cache.password` / `groundx.cache.username` helpers that
  mirror `groundx.db.password` exactly (`dig "password"/"username" "" .Values.cache`). Empty by
  default.
- Add the same pair, independently, on the two other addressable cache identities that can point
  at a *different* Redis instance than the main cache:
  - `cache.metrics.password` / `cache.metrics.username` (own value when `cache.metrics.enabled`
    is true — the same condition `groundx.metrics.cache.addr` already uses to decide whether
    metrics has its own instance; inherits the main cache's credential otherwise).
  - `ranker.cache.password` / `ranker.cache.username` (own value when `ranker.cache.addr` is
    set — the same condition `groundx.ranker.cache.existing` already uses; inherits the main
    cache's credential otherwise).
  Each identity's credential fallback exactly mirrors that identity's existing `addr` fallback,
  so a rendered credential always matches the Redis instance it authenticates to.
- Render the credential **inline** into the config resources that are already `kind: Secret` on
  0.2.7 (per GX-17) — no new Secret resource, no `envFrom`, no `secretRef`, no
  `cache.existingSecret`:
  - `templates/resources/config-yaml.yaml` — the main cache session block (`rec.session`, the
    cashbot-go shared-session client) and the metrics session block
    (`metrics.session`), each guarded independently (`{{- if ne (password) "" }}`, mirroring the
    existing `db.password` / upload-credential guard pattern already in this file).
  - `templates/resources/{layout,ranker,summary,workspace}-config-py.yaml` and
    `extract-config-py.yaml` — embed `[username:]password@` into the broker/result-backend URLs
    those files already build from `groundx.cache.*` / `groundx.metrics.cache.*` /
    `groundx.ranker.cache.*`, with the username/password percent-encoded (Sprig `urlquery`) so a
    URL-reserved character in the credential survives.
  - `groundx.workspace.celeryBrokerUrl` / `groundx.workspace.celeryResultBackend`: inject the main
    cache credential only into the **fallback** branch (the URL these helpers already build from
    `groundx.cache.*` when `workspace.celeryBrokerUrl`/`celeryResultBackend` is unset); a
    user-supplied full URL is never rewritten.
- Add `password`/`username` string properties (default `""`, matching `db`/`search`) to
  `cache`, `cache.metrics`, and `ranker.cache` in `values.schema.json` — all three currently
  declare `additionalProperties: false`.
- Document the new keys in `values.yaml` with a concise one-line comment each, matching the
  existing `db`/`search` documentation style — no verbose `NOTE` blocks, no commented-out example
  config (the repeated over-commenting flag from Ben's comment).
- Extend `values/values.existing.yaml` (both mirrors) — the shared "external services" values
  overlay already `-f`'d by eight existing `helm-unittest` suites (`cache_test.yaml`,
  `resources_test.yaml`, `golang_test.yaml`, `metrics_test.yaml`, `celery_test.yaml`,
  `inference_test.yaml`, `stream_test.yaml`, `api_test.yaml`) — with a password/username on its
  existing `cache:` and `cache.metrics:` external-Redis blocks, so the full-chart render test Ben
  requires ("extend an existing test... values file") lands as one edit that exercises the new
  behavior across every suite that already renders against it, rather than a new isolated
  snapshot file.
- Apply every change identically to both chart mirrors (`src/groundx/` and `helm/`); with no
  credential set, both mirrors keep rendering byte-identical to 0.2.7.

**Not in this proposal** (per Ben's comment, corrected from this ticket's original bespoke plan):
`cache.existingSecret`, any per-identity `existingSecret` variant, a `secrets.tpl` assembly, a
fail-loud "username requires password" guard, or any env-var/`envFrom`/`secretRef` delivery path.
`workspace.existingSecret` / `tls.existingSecret` are a different (env-var/TLS-shaped) credential
class and are not reused here. cashbot-go's own `Username` field, ai-server's `status.py`
credential parse, and the arcadia/workspace-runner broker-URL verification are separate repos'
changes, tracked in their own OpenSpec changes; this proposal covers only the chart's render side.

## Capabilities

### New Capabilities
- `redis-authenticated-credentials`: per-cache-identity optional password/ACL-username values,
  rendered inline (guarded, default-off) into the already-`Secret` config resources and Celery
  broker/result URLs that each identity's consumers already read, with the credential fallback
  for each identity mirroring that identity's existing address-fallback shape.

### Modified Capabilities
- none — `values-contract-semantics` and `deployment-config` describe the existing values
  surface and config-render behavior generally; this change adds new optional keys and new
  guarded render branches without changing any existing documented requirement, so no delta
  against those specs is needed.

## Impact

- **Blast radius**: chart-only; default-off. With no `cache.password`/`cache.username` (and no
  per-identity overrides) set, every rendered manifest and config file is byte-identical to
  0.2.7 and every existing on-prem install (dev/staging/prod, any cluster type) is unaffected —
  this is purely additive surface for the operator who opts in. An operator who does set a
  credential must set it consistently with the Redis instance actually deployed/pointed to per
  identity; a mismatched credential (e.g. main cache credential applied where ranker's `cache`
  points at a different, uncredentialed instance) would only affect the identity misconfigured,
  and rolls back exactly like any other config-hash-triggered pod restart (`helm rollback`
  reverts the values, the config-hash annotation forces the affected pods to roll back to the
  prior rendered config on the next apply).
- **Stateful-resource impact**: no schema/migration and no change to a customer's *external* Redis
  (`cache.existing.addr`), whose own `requirepass`/ACL config the customer owns. For a *chart-created*
  (in-cluster) `cache`/`cache.metrics` with a credential set, the change renders one new
  per-identity `redis.conf` Secret (`cache-conf` / `cache-metrics-conf`) and configures that
  in-cluster server to require the credential; with no credential set nothing new renders (default-off
  byte-identical). The client-side credential goes into the values rendered into the six
  already-`Secret` config resources listed above.
- **Cross-service dependency**: cashbot-go already reads a shared `config.Redis.Pass`, so the
  password-only path (case 1) works against 0.2.7 cashbot-go with no app change; the ACL-username
  path (case 2) needs cashbot-go's own `Username` field addition (tracked separately) before it
  takes effect for the cashbot-go session client. ai-server's Celery brokers authenticate via the
  URL with no app change (subject to the cross-service spike's `held` result); its direct
  `status.py` Redis client needs its own parse change (tracked separately) before a
  status.py-only credential takes effect. Rollout order between this chart change and the
  consumer app changes does not matter for the additive, default-off path: an operator only sets
  a credential once the consuming app version that reads it is deployed.
- **Affected files** (both `src/groundx/` and `helm/`, byte-identical edits):
  `templates/_helpers/services/cache.tpl` (new `groundx.cache.password`/`username` helpers),
  `templates/_helpers/services/db.tpl`-style additions to the metrics block of `cache.tpl`
  (`groundx.metrics.cache.password`/`username`), `templates/_helpers/app/ranker.tpl`
  (`groundx.ranker.cache.password`/`username`), `templates/_helpers/app/workspace.tpl`
  (credential injected into the existing `celeryBrokerUrl`/`celeryResultBackend` fallback),
  `templates/resources/config-yaml.yaml`, `templates/resources/{extract,layout,ranker,summary,
  workspace}-config-py.yaml`, `values.yaml`, `values.schema.json`, `values/values.existing.yaml`,
  and the corresponding `helm-unittest` suites under `tests/` (`src/groundx/` only — `helm/` has
  no `tests/` tree, per the mirror convention).
- **Quality gates**: `.build/bin/validate-helm.sh` (lint + `helm unittest` snapshot tests +
  dual-surface render checks) must stay green for both chart surfaces; `helm-unittest` snapshots
  touched by the `values/values.existing.yaml` change are regenerated with
  `helm unittest -u src/groundx` and reviewed for the expected credential diff only.

## Open design questions

None — the credential paradigm (config-file-as-Secret, no env-injection), the per-identity
fallback shape, and the workspace URL-scoping rule are already resolved in the workspace-level
cross-service design (R1/R2/R3), confirmed against this repo's actual 0.2.7 code during this
proposal's authoring (see the file/line citations above).
