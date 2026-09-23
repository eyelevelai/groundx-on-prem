## Goals / Non-Goals

**Goals:**
- Let an operator opt into cashbot-go's new `local` identity mode from the chart, by rendering
  whatever value they set for `cognito.mode` into the deployed `config.yaml`.
- Keep every install that does not opt in byte-for-byte unaffected (additive, opt-in, no default
  block).
- Keep `src/groundx/` and `helm/` byte-identical for every file this change touches, per the
  chart's existing manual-mirror convention (there is no regen script).

**Non-Goals:**
- Anything on the cashbot-go side (the `local` enum value, password hashing, the no-token/
  admin-reset behavior, the `partner_users.password` column) — that is the producer's change,
  tracked in cashbot-go's own OpenSpec change.
- Rendering `Cognito.AdminPassword`/`ClientID`/`ClientSecret` or any other cognito-mode-specific
  field — only `mode` is in scope; the real `cognito` mode's existing (absent) rendering is
  untouched.
- A new backing service, pod, PVC, public status lifecycle, or reaper — this is a values/template
  addition only.
- Strict enum validation on `cognito.mode` in the chart's `values.schema.json` (see Decision 3).

## Decisions

### 1. New helper lives in `main.tpl`, not `app/groundx.tpl`
The proposal named `templates/_helpers/app/groundx.tpl` as the home for the new
`groundx.cognito.mode` helper. Grounding against the actual codebase shows that file
(`app/groundx.tpl`) is the per-component helper set for the `.Values.groundx` block (the `groundx`
service pod itself — `groundx.groundx.serviceName`, `.node`, `.image`, …), not a home for
standalone top-level values keys. The existing precedent for a standalone top-level key —
`admin.apiKey` / `admin.email` / `admin.password` / `admin.username` — lives in
`templates/_helpers/main.tpl`. `cognito.mode` is the same shape (a standalone top-level values
block, not a per-service block), so `groundx.cognito.mode` is defined in `main.tpl` alongside the
`groundx.admin.*` helpers:
```
{{- define "groundx.cognito.mode" -}}
{{- $in := .Values.cognito | default dict -}}
{{- dig "mode" "" $in -}}
{{- end }}
```

### 2. No default `cognito:` block in `values.yaml`
`admin` is the closest precedent for an optional, security-adjacent top-level block: it is fully
documented in `src/groundx/README.md`'s values table but has **no** default key in `values.yaml` at
all — an operator adds it only when they need it. `cognito` follows the same pattern: no
`cognito:` block ships in `values.yaml`; the key exists only in `values.schema.json` (so
`additionalProperties: false` accepts it) and in the README. This keeps the change strictly
additive at the file-diff level — `values.yaml` itself does not change.

### 3. `values.schema.json`: plain string, no enum
The chart's job is to render whatever value the operator sets — enum-level validation of
`apiKeyOnly`/`cognito`/`local` is cashbot-go's own `Validate()` at the producer, per the contract's
`Compatibility: Additive` classification. Pinning an enum in the chart's schema would couple the
two repos' release cadence (a fourth cashbot-go mode would need a chart schema change just to be
settable) for no observable benefit this ticket asks for. `cognito.mode` is added as
`{ "type": "string" }` under a new `cognito` object (`additionalProperties: false`, matching every
other block in this schema), not as an enum.

### 4. Render position: alphabetical, same conditional-block pattern as `admin`
`config-yaml.yaml`'s top-level keys render in alphabetical order (`admin`, `ai`, `engines`,
`environment`, `groundxServer`, …). `cognito` sorts between `ai` and `engines`, so the new block is
inserted there, guarded the same way the existing `admin:` block is guarded (a single
`{{- if ne (include "groundx.cognito.mode" .) "" }} ... {{- end }}`, trimmed so an unset install
adds no blank line and no key):
```
{{- if ne (include "groundx.cognito.mode" .) "" }}

cognito:
  mode: {{ include "groundx.cognito.mode" . }}
{{- end }}
```

### 5. No snapshot regeneration expected (verified, not assumed)
The proposal called for regenerating `src/groundx/tests/__snapshot__/*.snap`. Grounding this
against the actual template shows it is unnecessary: the new conditional block, like the existing
`admin:`/`workspace:` conditionals it mirrors, renders nothing when unset, so every existing
`matchSnapshot` scenario in `resources_test.yaml` (none of which set `cognito.mode`) renders
byte-identical output before and after this change — verified directly: a `notMatchRegex` assertion
for `cognito:` against today's unmodified template already passes (see the acceptance-check task
below). No `.snap` file is expected to change. If implementation nonetheless causes drift, that
surfaces as a `helm unittest src/groundx` failure (the task's own check), which is a signal to fix
the template's placement/trimming, not to blindly regenerate the snapshot — `helm unittest -u` is
only ever run to intentionally reflect a decided-and-reviewed rendering change, never to paper over
an unexplained diff.

### 6. Acceptance tests extend `resources_test.yaml`, not a new suite file
`config-yaml.yaml` only renders correctly when helm-unittest is given the same ~20-template list
`resources_test.yaml` already assembles (its helpers transitively require the other resource
templates to be loaded into the same suite — confirmed by trying a narrower template list, which
fails with an unrelated "no template … associated" error). Reusing the existing suite (three new
`it:` cases appended, same template list, `../values.yaml` plus `set: cognito.mode: …`) is both the
correct mechanism and the Test-economy-mandated reuse of an existing package test rather than a
parallel harness.

## Risks / Trade-offs

- **[Risk]** An operator sets `cognito.mode: local` against a cashbot-go image that predates
  `local`-mode support (rollout-order mismatch). → **Mitigation:** the contract classifies both
  sides `Additive`, deployable in either order; cashbot-go's own `Validate()` rejects an unknown
  enum value at that binary's startup — a chart-side concern only insofar as the README should tell
  the operator to upgrade cashbot-go before setting the value (covered in the docs task).
- **[Risk]** A future operator expects the chart to reject a typo'd `cognito.mode` value at
  template time. → **Mitigation:** accepted as out of scope (Decision 3); the failure surfaces at
  the cashbot-go pod's own startup validation instead of at `helm template` time. If this proves too
  late in practice, tightening the chart schema to an enum is a small, additive follow-up.
- **[Risk]** `helm/`'s `tests/` directory does not exist (removed in the manual mirror), so the new
  acceptance tests only run against `src/groundx/`. → **Mitigation:** the mirror task's check
  independently renders the `helm` chart with `--set cognito.mode=local` and asserts the same output,
  so the `helm/` surface is verified behaviorally even without its own test suite.

## Migration Plan

- **Rollout:** an operator upgrading to opt into `local` mode sets `cognito.mode: local` and runs
  the existing chart upgrade path; this only changes the rendered `config-yaml-map` ConfigMap,
  which the existing deployment already picks up via its normal rolling pod restart on a config
  change — no new rollout mechanism.
- **Ordering:** independent of cashbot-go's own deploy (both additive); see the rollout-order risk
  above.
- **Rollback:** unset `cognito.mode` (or pin the prior chart version). Because the block is
  gated on `ne ... ""` and never persists any state outside the rendered ConfigMap, rollback leaves
  no residual chart-rendered state — the next render simply omits the `cognito` key again.

No ADR: this is a mechanical, precedent-following chart addition (mirrors the existing `admin`
block's values/schema/template/doc pattern) with no novel architectural decision beyond what is
recorded above.
