## Goals / Non-Goals

**Goals:**
- Give each of the five ConfigMap-bound credential families (OpenSearch, summary API key, Redis
  AUTH, application API keys, Google OCR credential) an opt-in Kubernetes-Secret path, additive and
  backward compatible, with the matching `values.schema.json` allowance.
- Keep the existing plaintext/ConfigMap path working exactly as it renders today when nothing new
  is set — verified by `helm template` diffs, not asserted.
- Update `src/groundx/` and its manual mirror `helm/` together, byte-identically, in the same
  change.

**Non-Goals (per the approved proposal — not re-litigated here):**
- No application-code change. Whether each workload actually prefers a non-empty config value over
  an env/Secret-sourced fallback is owner-asserted (Ben), not verifiable from this repo.
- No GX-11 `celery.yaml` render-bug fix — see the OCR decision below for how this design avoids
  that file's guarded lines entirely rather than requesting an exception to touch them.
- No credential rotation, no GX-10 guidance-doc work, no new subsystem/table/queue/status-lifecycle.

## Decisions

**Invariant (gate class — this change adds a rendering rule applied at 5 sites: `groundx`,
`extract.agent`, `extract.download`, `extract.save`, `ranker.api`/`ranker.inference`):** a
credential's Secret-backed env/volume is wired into a pod's environment or filesystem, and its
plaintext form is omitted from any ConfigMap-rendered config, **exactly when the plaintext value
for that credential is empty** — a non-empty plaintext value always renders into the ConfigMap and
is what the app is asserted to prefer; the Secret path only ever adds a runtime fallback for when
the config value is empty, and never suppresses a plaintext value that is actually set. This is
the one rule implemented identically across all five families below; the catches/must-not-block
scenarios in `specs/credential-secret-paths/spec.md` are the executable proof of it (a naive
`if existingSecret then omit` implementation would fail the "catches" scenario for every family).

### D1 — Two independent toggles per family, not one
Each family gets two independent conditions, deliberately decoupled:
1. **Does the plaintext key render into the ConfigMap?** Gated purely on whether the plaintext
   value is non-empty (already true for `admin.*`/`summary.existing.apiKey`/`ai.openai.apiKey`
   before this change — see D3 for why OpenSearch needs a code change here and the others don't).
2. **Is the Secret/env/volume wired into the pod at all?** Gated purely on the new
   `existingSecret` boolean, independent of the plaintext value.

Combining them orthogonally is what makes "config wins even when existingSecret is set" (the
catches scenario) fall out for free, instead of needing a third precedence branch hand-coded per
family.

### D2 — Chart-side Secret creation only where the plaintext default is empty
Precedent (`extract.agent.existingSecret`, `extract.save.existingSecret`) auto-creates a Secret
from the plaintext value whenever it is non-empty **and** `existingSecret` is false — safe there
because `extract.agent.apiKey`/`extract.save.gcpCredentials` default to `""`, so the auto-create
branch never fires on a default install.

- **Summary, Redis, application API keys**: all three of `summary.existing.apiKey`,
  `cache.existing.password` (new field), and `admin.apiKey`/`admin.username` default to `""` too —
  mirror the `extract.agent` auto-create pattern exactly (this is what the proposal calls for
  summary: "mirroring the existing extract.agent → GROUNDX_AGENT_API_KEY pattern").
- **OpenSearch is the deliberate exception.** `search.password`/`search.username`/
  `search.privilegedPassword`/`search.privilegedUsername` default to **non-empty** literals
  (`R0otb_*t!kazs` / `eyelevel` / `admin`) in `values.yaml` today. Mirroring the auto-create
  pattern here would fabricate a new `opensearch-secret` Secret resource on every default install —
  a manifest diff with nothing set, which breaks the "must not block: default install renders
  unchanged" scenario. So OpenSearch's Secret is **only** ever referenced when
  `search.existingSecret=true` is explicit; the chart never auto-creates it from the default
  plaintext values. This is called out explicitly because it is the one family where copying
  precedent verbatim would have been wrong — a genuine code-grounding finding from reading
  `values.yaml`, not from the proposal text.
- **OCR** has no plaintext-value auto-create branch at all (see D5) — the credential is a packaged
  file path, not a values.yaml string suitable for Secret-ifying automatically.

### D3 — OpenSearch: `config-yaml.yaml` must become conditional (a real code change)
`ai.aws.search.{username,password}` (lines ~127-128) and `init.search.{username,password}` (lines
~228/230) render **unconditionally** today, unlike `admin.*` and `ai.openai.apiKey`, which are
already conditional on non-empty (`{{- if ne (include ...) "" }}`). This change makes the four
OpenSearch fields conditional the same way, mirroring the existing `admin`/`openai` pattern in the
same file rather than inventing a new one.

### D4 — Redis AUTH rides the chart's existing global-secret mechanism; no per-pod wiring
`groundx.secrets` (`_helpers/main.tpl`) already turns `cluster.secrets` (a plain list of
pre-existing Secret names) into a dict that every one of the five app pod templates
(`api.yaml`, `celery.yaml`, `golang.yaml`, `inference.yaml`, `metrics.yaml`) merges into its own
`envFrom` — confirmed by grep, all five call `include "groundx.secrets"`. Redis/broker
connectivity is already the most universal per-pod dependency in the chart (every `celery.yaml` pod
waits for cache unconditionally, not gated by its `dependencies` dict). Given that blast radius is
already structurally universal, folding the Redis Secret name into `groundx.secrets` itself (one
function, one file) reaches every pod for free — zero edits to any of the five pod templates or to
any per-pod `.settings` helper. This was verified by reading `groundx.secrets`'s call sites before
choosing it over hand-wiring `cache`'s Secret into each `.settings` function, which would have
touched ~9-14 files for no documented reason to scope it any narrower.

By contrast, OpenSearch/summary/admin credentials are **not** folded into this universal mechanism:
only the `groundx` pod declares a dependency on `search` anywhere in the chart (grep confirms no
other `.settings` helper references `"search"`), and no pod declares a `summary` dependency at all.
Routing those through the global mechanism would hand every workload (`layout-ocr`, `extract-save`,
etc.) an OpenSearch/OpenAI credential it has no documented need for — unnecessary blast radius the
per-pod `secrets` dict (the same mechanism `extract.agent`/`extract.save` already use) avoids.

### D5 — OCR: additive Secret volume via the existing generic extension point; celery.yaml is not touched
`templates/app/celery.yaml` already has an untouched, generic extension point: each pod's
`.settings` helper may set `volumes`/`volumeMounts` keys, which the loop appends unconditionally
after the fixed `config-volume`/`credentials-volume`/`supervisord-volume` block (lines ~182-184,
~197-199) — used today by, e.g., `extract.agent.settings`. Because `layout.ocr` is rendered
**only** through `celery.yaml` (confirmed via `groundx.celery.process.services`), adding the new
Secret volume/mount to `groundx.layout.ocr.settings`'s `volumes`/`volumeMounts` entries reaches the
`layout-ocr` pod without a single line changed in `celery.yaml` — **the GX-11 `hasOCR`
`-}}`-guarded conditional (lines ~66-68, ~174-178, ~189-193) is never opened.** This was the
explicit boundary condition in this ticket's brief; the generic extension mechanism satisfies it
by construction rather than by care taken while editing.

Because both the existing ConfigMap-file mount and the new Secret-volume mount would target the
same container path (`/app/credentials.json`), `groundx.layout.ocr.settings` (or a small validation
helper it calls) `fail`s the render when both `layout.ocr.credentials` and
`layout.ocr.existingSecret` are set — mirroring the chart's existing `fail` convention
(`groundx.extract.agent.validateImageSettings`) rather than silently letting one clobber the other
or shipping a duplicate-mountPath manifest.

### D6 — Application API keys: `admin.existingSecret`, not a new `cluster`/per-service key
`callback_api_key`/`api_key`/`valid_api_keys` (extract) and `validAPIKeys` (ranker) all source from
`admin.apiKey`/`admin.username` (confirmed by reading `extract-config-py.yaml`/
`ranker-config-py.yaml`; `cluster.validApiKeys` supplies only supplementary extra keys and is out of
scope — the proposal names `api_key`/`callback_api_key`/`valid_api_keys`/`validAPIKeys`, not the
extras list). The single new boolean lives on the `admin` block (`admin.existingSecret`), the
block that actually owns the two source values, rather than introducing a second toggle location.
When `existingSecret=true` and the sourced value is empty, the rendered Python switches from a
quoted literal to `os.environ.get("GROUNDX_ADMIN_API_KEY", "")` / `os.environ.get(
"GROUNDX_ADMIN_USERNAME", "")` — evaluated by the container's own Python interpreter at startup, so
this is chart-authored, deterministic Python we fully control (requires adding `import os` to the
generated module header), not an app-code change. **What remains owner-asserted and unverified from
this repo** is only the two environment-variable **names** (`GROUNDX_ADMIN_API_KEY`,
`GROUNDX_ADMIN_USERNAME`) and the `SEARCH_*`/`REDIS_AUTH` names above — Ben confirms these at PR
review per the source-of-truth table; the mechanism delivering them is verified in-chart.

### D7 — Fixed, non-overridable Secret names (minimal schema footprint)
Per family, the Secret name is a fixed literal (`opensearch-secret`, `summary-secret`,
`redis-secret`, `groundx-admin-secret`, `layout-ocr-secret`) rather than an overridable
`secretName` key. The proposal's instruction to "relax `additionalProperties:false` only for that
one new key" per family is honored literally this way — each family adds exactly the
`existingSecret` key (plus `cache.existing.password`, the one plaintext field the proposal itself
names). An operator who needs a different Secret name pre-creates it under the fixed name; this
matches the granularity the ticket asked for and avoids a second schema key per family with no
requirement driving it.

### D8 — Mirror sync
`src/groundx/templates`, `src/groundx/values.schema.json` are today byte-identical to
`helm/templates`, `helm/values.schema.json` (verified: `diff -rq` and `diff` both empty). Every
template/schema edit below is applied to `src/groundx/` first and then copied verbatim to the
matching `helm/` path in the same task (see tasks.md); `helm/`'s own `tests/` directory does not
exist (removed in the mirror) so no test duplication is needed there.

## Risks / Trade-offs

- **[Risk] The five owner-asserted env-var names (`SEARCH_*`, `GROUNDX_SUMMARY_API_KEY`,
  `REDIS_AUTH`, `GROUNDX_ADMIN_API_KEY`, `GROUNDX_ADMIN_USERNAME`) may not match what the private
  application images actually read.** → Mitigation: flagged explicitly in the PR for Ben's
  confirmation (source-of-truth table already records this); `REDIS_AUTH` is the one name the
  Linear ticket body specifies verbatim, lowering its risk. Because the plaintext/config path is
  unchanged and still wins, a wrong env name degrades to "the Secret path silently does nothing
  extra" rather than breaking the plaintext/dev path.
- **[Risk] `admin.existingSecret` does not cover `extract.callbackApiKey`/`layout.callbackApiKey`
  when those are set independently of `admin.username`.** → Mitigation: out of scope per the
  proposal's literal framing (`admin.apiKey`/`admin.username`/`cluster.validApiKeys`); noted here
  rather than silently expanded.
- **[Risk] `helm/` mirror drift if a future PR touches `src/groundx/` without this ticket's
  discipline.** → Pre-existing, tracked gap (`service.yaml` `known_gaps`); unaffected by this
  change, not fixed here (no regen script exists to build).
- **[Trade-off] Fixed Secret names (D7) reduce flexibility for an operator who wants a
  differently-named Secret per family.** → Acceptable: matches the schema-footprint instruction in
  the proposal; an override key can be added later as its own additive change if requested.

## Migration Plan
No stateful resource, migration, or schema change to any backing datastore is involved — this is
chart-template and `values.schema.json` surface only. Every new field defaults to unset/false, so
an existing release upgrading to a chart version carrying this change renders unchanged manifests
until an operator opts in per family (verified by the "must not block: default install" scenario in
each family's spec). Rollback is a plain `helm rollback` / chart-version downgrade; no data
migration, no `NOT NULL`-style hazard. Ships only via an official chart release, consistent with the
proposal.

## Open Questions
None outstanding beyond the owner-asserted env-var names already tracked above and in
`.sdd-state/GX-17/source-of-truth.md` for Ben's PR-review confirmation.
