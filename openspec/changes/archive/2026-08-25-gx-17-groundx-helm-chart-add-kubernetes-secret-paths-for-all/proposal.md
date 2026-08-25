## Why

Chart 0.2.6 Secret-backs some credentials (`GROUNDX_*`/`MYSQL_*` via `cluster.secrets`) but renders
five other credential families into plaintext `ConfigMap`s with no Kubernetes Secret path at all:
OpenSearch creds, the summary API key, the application API keys (extract/ranker), and the Google
OCR service-account JSON — and Redis AUTH cannot be configured at all today. These are not
encrypted at rest by default (etcd encryption is an interim stopgap, not the fix) and were verified
live on a running cluster (GX-18). Ben's GX-4 review requires that any credential still needed by a
workload use a supported Kubernetes Secret path, not a ConfigMap. This ticket is the single
chart-code change that fully remediates GX-18, ships as its own PR (kept separate from the GX-11
`celery.yaml` render-bug fix per Ben's instruction), and lands only via an official chart release.

## What Changes

All changes are **additive and opt-in** — the existing plaintext values stay as the dev/default
path, "config-wins-else-env" precedence is preserved everywhere (a non-empty config value wins;
otherwise the workload reads the Secret-injected env/volume), and no chart-version bump is forced.

- **OpenSearch** — add a `search.existingSecret` hook and `SEARCH_*` env injection alongside
  `search.{username,password,privilegedUsername,privilegedPassword}` (today rendered as literal
  values into `config-yaml.yaml`, e.g. `username`/`password` at lines 127-128 and the privileged
  pair at lines 228/230). `search.additionalProperties:false` currently has no `existingSecret`
  key (`values.schema.json:299-322`) — relax it only for that one new key.
- **Summary API key** — give `summary.existing.apiKey` a real Secret + `envFrom`, mirroring the
  existing `extract.agent` → `GROUNDX_AGENT_API_KEY` pattern already implemented in
  `_helpers/app/secrets.tpl` and `_helpers/app/extract-agent.tpl` (today the key renders as a
  literal `ai.openai.apiKey` value in `config-yaml.yaml:149-150`, no `existingSecret` hook).
  `summary.existing.additionalProperties:false` (`values.schema.json:492-500`) has no
  `existingSecret` key today — relax it only for that key.
- **Redis AUTH** — add `cache.existing.password` plus a `REDIS_AUTH` env sourced from a Secret, for
  an **external** Redis only; the chart-bundled Redis stays auth-less (no change to that
  deployment). `cache.existing.additionalProperties:false` (`values.schema.json:139-149`) currently
  rejects any `password` key — add it there.
- **Application API keys** — Secret-inject env for the plaintext values that today render as
  literal Python into ConfigMaps: `extract-config-py.yaml`'s `callback_api_key` / `valid_api_keys` /
  `api_key` (snake_case, sourced from `groundx.admin.apiKey` / `groundx.admin.username` /
  `cluster.validApiKeys`) and `ranker-config-py.yaml`'s `validAPIKeys` (same sourcing).
- **Google OCR credential** — add a `layout.ocr.existingSecret` Secret-volume mount for the GCP
  service-account JSON, alongside the existing packaged-ConfigMap dev path (today mounted from a
  ConfigMap named `<svc>-ocr-credentials-map` at `/app/credentials.json` via a `credentials-volume`
  in `templates/app/celery.yaml`) — the packaged-file path is retained, not removed.
  `layout.ocr.additionalProperties:false` (`values.schema.json` layout block) has a `credentials`
  key but no `existingSecret` key today — add it.
- **Schema allowances** — for each of the five families above, relax `additionalProperties:false`
  **only** at the specific new key being introduced; no other schema surface changes.
- **Both chart surfaces** — `src/groundx/` (source of truth) and `helm/` (its manual, unguarded
  mirror) are updated together in this change; the mirror sync is in scope, not deferred.

**Explicitly out of scope** (per the approved plan — not re-litigated here):
- Any application-code change. Whether/how each workload actually reads the Secret-injected
  env/volume when config is empty is **owner-asserted** (Ben), not verifiable from this repo — the
  consuming code lives in private container images outside this workspace. Env-var names with no
  in-chart precedent (`SEARCH_*`, `REDIS_AUTH`, the application API key env names) are recorded as
  explicit owner-asserted assumptions for Ben to confirm at PR review; only the summary key
  (mirrors `extract.agent`) and the OCR credential (mirrors the existing volume-mount pattern) have
  direct in-chart precedent.
- GX-10's harness/guidance-doc lane.
- The GX-11 `celery.yaml` render-bug fix — ships as a separate PR.
- Credential **rotation**. Shipping these Secret paths does not itself rotate the already-exposed
  values on any running cluster; that follow-up is tracked on GX-18/GX-20, not here.

## Capabilities

### New Capabilities
- `credential-secret-paths`: opt-in Kubernetes-Secret paths — `existingSecret` hooks plus the
  matching env/volume injection — for the five ConfigMap-bound credential families (OpenSearch,
  summary API key, Redis AUTH, application API keys, Google OCR service-account JSON), preserving
  config-wins-else-env precedence, with the corresponding `values.schema.json` allowances on both
  `src/groundx/` and `helm/`, validated by `helm lint` + `helm template` rendering cleanly across
  Secret-set / plaintext-set / absent value combinations.

### Modified Capabilities
(none — no existing `openspec/specs/` capability's requirements change; `values-contract-semantics`
documents unrelated deprecated-field compatibility and is unaffected by this change)

## Impact

- **Code:** `src/groundx/values.schema.json` (`search`, `cache.existing`, `summary.existing`,
  `layout.ocr` blocks) and its mirror `helm/values.schema.json`; `templates/resources/config-yaml.yaml`
  (OpenSearch + summary rendering); `templates/resources/extract-config-py.yaml` and
  `templates/resources/ranker-config-py.yaml` (application API key sourcing);
  `_helpers/app/secrets.tpl` (new Secret-emission entries, mirroring the existing
  `extract.agent`/`extract.save` entries); `_helpers/app/layout-ocr.tpl` plus the OCR
  celery/app-pod templates (new Secret-volume mount alongside the existing ConfigMap-volume mount);
  the per-pod `.settings` helpers for the affected workloads (new env entries) — each mirrored into
  `helm/`.
- **Blast radius / environments:** every environment that deploys this chart — dev, staging, prod,
  and any self-hosted/air-gapped customer install — redeploys once this ships in a chart release.
  Affected Deployments (the OpenSearch-adjacent pods, extract, ranker, layout-ocr, summary) pick up
  changed ConfigMap/Secret references and roll via the chart's existing config-hash restart
  annotation. No stateful backing service (search index, database, object storage, cache data) is
  touched by this change — only credential plumbing into already-rolling app pods.
- **Rollback/rollforward:** because every new field is opt-in, a cluster that upgrades without
  setting any of the five new keys should render unchanged manifests for those blocks — this
  additive-parity property is the design's explicit target and will be checked by a `helm template`
  diff (default values, before vs. after) during the design/tasks phases, not asserted here.
  Rollback is therefore a plain chart-version downgrade or `helm rollback`, with no data migration
  and no `NOT NULL`-style compatibility hazard, since no required or removed field is involved.
- **Dependencies:** none outside this repo. Consuming application behavior is EXTERNAL and
  owner-asserted per the confirmed source-of-truth table, not verified here.
- **Open design questions:** none — decisions D1 (additive/opt-in only), D2 (proceed on
  owner-asserted precedence; record unverified env names as assumptions), and D3 (base =
  `origin/0.2.7`) were already approved in the brainstorming phase and are binding; the
  `superpowers:brainstorming` skill is not re-invoked for this proposal.

## Amendments

- **2026-08-25 — app-side changes required (this record's "application-code change: out of scope" is superseded).** Verification against the shipped 0.2.7 images, the live EKS deployment, and the cashbot-go/ai-server source showed the on-prem apps read OpenSearch, Redis, and the summary/OpenAI key **only from `config.yaml`**; the env fallback (cashbot-go `pkg/config/api.go LoadEnvVars`) covered only the admin API keys. The chart's Secret paths for OpenSearch/Redis/summary were therefore inert. The chart (this change) is correct and unchanged. Coordinated app-side fixes ship alongside it: cashbot-go `LoadEnvVars` now reads `SEARCH_USERNAME`/`SEARCH_PASSWORD`/`SEARCH_PRIVILEGED_*`, `REDIS_AUTH` (Rec + Metrics session), `GROUNDX_SUMMARY_API_KEY`; ai-server injects `REDIS_AUTH` into the Celery broker URLs (`redis_auth.patch_env`). Application API keys (`GROUNDX_ADMIN_*`) and Google OCR (file mount) already worked. All additive/opt-in and backward compatible. See the cross-service change folder's `contract.md` (External-semantics assumptions, now resolved) and `design.md`.
