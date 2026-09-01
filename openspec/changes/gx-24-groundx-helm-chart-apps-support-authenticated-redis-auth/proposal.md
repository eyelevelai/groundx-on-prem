# GX-24: groundx-on-prem chart support for authenticated Redis (AUTH password / ACL user)

- **Ticket**: GX-24
- **Author**: Nitin Vavdiya <nitin.vavdiya@smartsensesolutions.com>
- **Date**: 2026-09-01

## Why

The chart today assumes an auth-less Redis: it renders host, port, and TLS scheme but never a
credential. A customer pointing GroundX on-prem at their own external or managed Redis with
authentication enabled (AWS ElastiCache AUTH/RBAC, Azure Cache access key/ACL, GCP Memorystore
AUTH string, or an on-prem `requirepass` baseline) gets `NOAUTH` and the dependent services fail
to start. This is the producer half of GX-24: the two consumer repos already carry their sides on
separate branches (cashbot-go @ `eaee3388`, ai-server @ `f25ff87`, both implemented, verified, and
archived), so this chart change is what actually lets an operator opt in. It is the functional
complement to GX-17, which got GroundX's own credentials out of plaintext ConfigMaps; this ticket
lets GroundX consume a credential the customer's Redis requires.

## What Changes

- Add default-empty, Secret-backed Redis credential values, one pair per Redis identity the chart
  already tracks separately (matching each identity's existing addr/port/ssl helper shape in
  `cache.tpl` / `ranker.tpl`):
  - `cache.username` / `cache.password` (+ `cache.existing.username` / `.password` for an external
    Redis)
  - `cache.metrics.username` / `.password` (+ `cache.metrics.existing.*`) — defaults to inheriting
    the main `cache` credential, matching `groundx.ranker.cache.addr`'s existing addr-fallback
    pattern
  - `ranker.cache.username` / `.password` — same inheritance default
- Render the credential into the two cashbot-go `session:` config blocks (`config-yaml.yaml`
  `metrics.session` ~336-339 and `rec.session` ~616-619) as **raw, unencoded** `password:` /
  `username:` keys — cashbot-go's `config.Redis` (consumer side, already shipped) decodes YAML, not
  a URL.
- Render the credential into the three ai-server broker/result-backend URL pairs
  (`layout-config-py.yaml`, `ranker-config-py.yaml`, `summary-config-py.yaml`) and each template's
  `metricsBroker` URL, as `scheme://[username]:password@host:port/0`, with the username and
  password **percent-encoded** via Sprig `urlquery`. This is a spike-derived requirement (AGE-221,
  held): an unencoded reserved character in the password breaks URL parsing before AUTH is ever
  attempted, for both the kombu broker path and ai-server's `status.py` health client.
- Credentials apply to **external Redis only**: the render **fails loudly** (Helm `fail`) if a
  credential value is set while `groundx.cache.create == "true"` — the chart's bundled Redis has no
  documented in-chart mechanism to enable AUTH, so a silently-ignored credential would be worse
  than an explicit error.
- Declare every new key in `values.schema.json`, preserving `additionalProperties: false` on
  `cache`, `cache.existing`, `cache.metrics`, `cache.metrics.existing`, `ranker.cache`, and the
  schema root — an undeclared key must hard-fail the render, not silently pass through.
  Document the new keys in `values.yaml` and the `values/values.existing.yaml` example.
- Apply the identical delta to the `helm/` manual mirror. `helm/` carries pre-existing,
  unrelated drift (`Chart.yaml` 0.2.6 vs 0.2.7, one memory value) — this change does not touch
  that drift.
- Add new `helm unittest` cases covering credentialed renders (username+password, password-only,
  percent-encoding of a reserved-character password, and the fail-loud bundled-Redis case).
  Existing default-values snapshots under `src/groundx/tests/__snapshot__/` must render
  byte-identical — no snapshot is hand-edited; any legitimate snapshot change comes only from
  `helm unittest -u`.
- **BREAKING for an un-updated ai-server image only, and mitigated by the default-off gate**: an
  operator who sets `cache.password` before the ai-server image built from `f25ff87` is the image
  the 0.2.7 chart advertises will hit `status.py`'s pre-fix URL parser, which does not strip
  userinfo from a credentialed `metricsBroker` URL. This is why the chart PR must not merge ahead
  of that image being current for the 0.2.7 release (see Impact). No other consumer is affected:
  an install that never sets these values renders byte-identical to today.
- **Explicitly out of scope** (deferred follow-ups, not part of this change): `extract-config-py.yaml`
  and `workspace-config-py.yaml` broker templates (no current ticket requirement covers them); TLS
  server-certificate verification / mutual TLS (encryption already works; verification is a
  separate hardening effort); rotating/IAM token auth (ElastiCache IAM, Azure Entra ID — needs a
  credentials-provider callback, not a static Secret).

## Capabilities

### New Capabilities
- `redis-auth-credential-render`: chart-level rendering of a Secret-backed Redis AUTH password
  and/or ACL username+password, for each of the three Redis identities the chart already models
  (cache, cache.metrics, ranker.cache), into the cashbot-go cache config blocks (raw YAML keys) and
  the ai-server Celery/status broker URLs (percent-encoded userinfo). External-Redis-only,
  default-off, and byte-identical to 0.2.7 when unset.

### Modified Capabilities
(none — the existing `values-contract-semantics` capability's "Published and source chart surfaces
agree" requirement already generically covers the `src/groundx` ↔ `helm` mirror-parity obligation;
this change's own new capability carries its own mirror-parity scenario rather than editing that
spec's requirements.)

## Impact

- **Affected code**: `src/groundx/templates/resources/config-yaml.yaml`, `ranker-config-py.yaml`,
  `layout-config-py.yaml`, `summary-config-py.yaml`; the `cache.tpl` / `ranker.tpl` helpers backing
  the three Redis identities; `values.yaml`; `values.schema.json`; the
  `values/values.existing.yaml` example; plus the identical delta hand-synced into `helm/`.
- **Affected environments**: every K8s target this chart supports (eks, aks, gke, openshift,
  minikube) — the change is chart-template logic, not environment-specific config, so it applies
  uniformly wherever the `config-yaml-map` and `*-config-py-map` Secrets are rendered.
- **Data/stateful impact**: none. No schema or data migration; the rendered Secret content changes
  only for an operator who explicitly sets the new values. An upgrade that sets a credential
  triggers a pod restart through the chart's existing `config-hash` annotation mechanism (already
  in place for any config content change) — no new rollout mechanism is introduced.
- **Rollback/rollforward**: standard `helm rollback` to the prior chart revision. Because the
  change is purely additive template logic gated behind default-empty values, rolling back removes
  the rendered credential fields with no other side effects; roll-forward is the exact reverse. No
  irreversible state is created.
- **Blast radius**: scoped to this producer chart change. The two consumer repos are already
  implemented and archived on their own branches; this chart's `contract.md` records the
  cross-repo touchpoints and the one **rollout ordering constraint**: this chart PR targets the
  0.2.7 release branch and must not merge before the ai-server image tagged for that release
  carries the `f25ff87` `status.py` fix, because an operator opting in before then would hit the
  Breaking un-updated-image case named above. That ordering is a release-management fact, not a
  chart mechanic — nothing in this PR can enforce it directly.
- **Open design questions**: none. The plan-gate resolutions already fixed the scope and shape
  (E1-A: exactly which templates render credentials; E2-A: external-Redis-only + fail-loud on the
  bundled-Redis case; the per-identity-with-fallback credential shape; the percent-encoding
  requirement from the AGE-221 spike). `superpowers:brainstorming` is not invoked for this proposal.
