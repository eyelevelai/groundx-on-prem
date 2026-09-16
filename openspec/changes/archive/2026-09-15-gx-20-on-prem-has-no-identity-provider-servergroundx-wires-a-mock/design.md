See `proposal.md` for the current-state analysis (no `cognito:` anywhere in the chart today) and the FINALIZED `cognito` config-key contract this design renders against.

## Goals / Non-Goals

**Goals:**
- Render the FINALIZED `cognito` config-key contract (`mode`/`clientId`/`clientSecret`/`poolId`/`region`) into cashbot-go's `config.yaml` render, following the existing `admin:` block's per-key/whole-block conditional-render pattern exactly.
- Keep every existing on-prem install byte-identical on upgrade when it sets no `cognito.*` key.
- Keep `src/groundx/` ↔ `helm/` byte-identical for every touched file, including `values.schema.json` (a manual mirror this repo already maintains for the schema, confirmed identical today).
- Make the chart schema accept the new keys without weakening it beyond what the ticket needs.

**Non-Goals:**
- No cashbot-go change — the config-schema definition, `identity`/`cognito.mode` semantics, and startup validation are already implemented and FINALIZED in cashbot-go (`d7bf042`); this design only renders matching keys.
- No new Kubernetes resource. `cognito.clientSecret` is delivered through the existing `config-yaml-map` render, which has been `kind: Secret` since GX-17 — a second Secret/ConfigMap is not introduced.
- No `cognito.adminPassword` rendering path, and no change to `admin.password` / `config.Admin.Password` — both are out of scope per the ticket's assignee decision (source-of-truth.md).
- No enum/completeness validation of `cognito.mode` in the chart schema (see Decisions) — that is cashbot-go's `Cognito.Validate()` job, not the chart's.

## Decisions

- **No ADR.** The architectural decision (configurable Cognito opt-in + `apiKeyOnly` default, `cognito.mode` selector, no baked pool-id default) was made and is recorded in the workspace's `source-of-truth.md` and the cross-repo `contract.md`, and cashbot-go (the producing repo) owns any ADR for that decision. This design covers only the consumer-side chart-rendering mechanism, which introduces no new architectural choice — it follows the existing `admin:` block precedent byte-for-byte.
- **Render pattern: copy the `admin:` block's conditional structure exactly**, not a new pattern. `templates/resources/config-yaml.yaml:100-118` already does whole-block-guard + per-key-guard for `admin:`; `cognito:` uses the identical two-level `{{- if or (...) }}` / `{{- if ne (...) "" }}` shape so a reader of the file recognizes the idiom immediately, and so the "no cognito key set → byte-identical render" requirement falls out of the same mechanism the chart already relies on for `admin:` (verified: an install with no `admin.*` key set today renders no `admin:` block at all).
- **`cognito.mode` stays `type: string` in `values.schema.json` — no `enum` restriction.** The FINALIZED contract states cashbot-go treats "unset or any value other than the literal `cognito`" as `apiKeyOnly` (a tolerant selector, not a strict enum on the producer side). Adding an `enum: ["cognito", "apiKeyOnly"]` constraint at the chart-schema layer would reject a value cashbot-go itself tolerates — narrower than the producer's own contract and not required by the ticket. Matches the **design (scope discipline)** guardrail against introducing a stricter contract shape than the ticket calls for.
- **`cognito` schema object is `additionalProperties: false` with exactly five properties** (`mode`, `clientId`, `clientSecret`, `poolId`, `region`) — this is what makes `cognito.adminPassword` structurally unrenderable (schema-rejected, not silently dropped) without adding any dedicated adminPassword-blocking logic. Mirrors the existing `admin` object's shape (`values.schema.json:27-37`).
- **Consumer tolerant-reader check (CONSUMER touchpoint):** groundx-on-prem does not parse or validate a payload from cashbot-go at runtime — it renders a config file cashbot-go then loads via a plain YAML unmarshal into `config.Cognito` (`pkg/config/api.go`). There is no strict/pinned schema on cashbot-go's read side that could reject an additive field, so the "tolerant reader" concern does not apply in this direction; the risk that does apply (the chart's own `values.schema.json` being stricter than the contract, e.g. via an `enum`) is the decision above.
- **`values.schema.json` mirror confirmed in scope.** Read at design time: `helm template`/`helm lint` on the `helm` directory validates against `helm/values.schema.json` independently of `src/groundx/values.schema.json` (verified: both currently exist and are byte-identical). This file was not called out by name in the proposal's "Affected code" list but is mechanically required — the `helm` variant of the chart would otherwise reject the new `cognito` key even after `src/groundx/` is updated. Folded into the same mirror requirement as the two template files.
- **Sample-values scope confirmed unchanged.** `sample.values.yaml` documents the `cognito.*` keys and the `apiKeyOnly` default; `admin.password` stays exactly as it is today (ticket's assignee decision, reaffirmed in the workspace `design.md`) — this design makes no change to the `admin:` section.

## Rollout & removal plan

- **Rollout:** additive, any order. An install that upgrades the chart without setting any `cognito.*` key renders no `cognito:` key and is unaffected — verified structurally by the same guard mechanism `admin:` already uses. An install that wants Cognito sets all five `cognito.*` keys (chart does not enforce completeness; cashbot-go's `Cognito.Validate()` fails startup fast on a partial `mode: cognito` config).
- **Blast radius:** every environment that redeploys `config-yaml-map` re-renders it with the (empty-by-default) new block; no other rendered key changes. No stateful resource, no new Kubernetes object kind, no data-store migration in this repo.
- **Rollback:** `helm rollback` to the prior chart version stops rendering `cognito:` entirely; cashbot-go (deployed independently) falls back to its own `apiKeyOnly` default with no data loss, since this change introduces no persisted on-prem state.
- **Removal plan:** none — additive, no old shape retired (matches the FINALIZED contract's "Removal plan: n/a").

## Risks / Trade-offs

- **Schema drift between `src/groundx/values.schema.json` and `helm/values.schema.json` is unenforced** (no regen guard exists in this repo for either mirror). Mitigated only by the task-level `diff -q` check at authoring time; a future edit to either file independently would silently reintroduce drift. Out of scope to fix the mirroring mechanism itself (ticket guardrail: "do not fix the mirroring mechanism in this ticket").
- **The chart cannot validate `mode: cognito` completeness** — an operator who sets `mode: cognito` with only `clientId` will get a render that "looks fine" from `helm template`/`helm lint`, and the failure surfaces only at cashbot-go startup (`Cognito.Validate()`). This is the FINALIZED contract's own design (chart renders, producer validates) — documented in `docs/` so an operator is not surprised.
- **Cloud rollout dependency** (no baked `poolId` default) is a cashbot-go/production-rollout concern, not a chart-side risk; flagged in the workspace `tasks.md` hand-off section, out of this repo's build scope.

## Amendments

### 2026-09-16 — review-fix round 1

- **Supersedes the Decisions-section item "`cognito.mode` stays `type: string` — no `enum`
  restriction."** A human reviewer directed (review finding F2) that `cognito.mode` be
  constrained to `enum: ["cognito", "apiKeyOnly"]` in `values.schema.json` and its
  `helm/values.schema.json` mirror. This is a chart-schema-layer typo guard, not a change to
  the wire contract with cashbot-go: the chart already only ever renders whatever literal
  string an operator puts in `cognito.mode` (or nothing, unset), and cashbot-go's own
  `Cognito.Validate()`/tolerant-read fallback is unaffected either way — the enum only stops a
  clearly-mistyped value (e.g. `cognitoo`) from silently rendering and then silently degrading
  to `apiKeyOnly` at cashbot-go startup with no operator-visible error. `cognito` remains fully
  optional; the enum constrains the value only when the key is present. Implemented as task 1.3
  in `tasks.md`, with `src/groundx/tests/files/values.cognito-bad-mode-rejected.yaml` as the
  committed rejection fixture.
- **G1 fix: `sample.values.yaml` default changed from an active `cognito:` block to a fully
  commented-out example.** The original `sample.values.yaml` shipped `cognito.mode: cognito`
  with four placeholder values as the *active* default — a customer copying the file unmodified
  would land in `mode: cognito` with placeholder credentials and hit cashbot-go's startup-fatal
  validation. The block is now commented out in its entirety (all five keys shown, with a note
  to uncomment and fill them to enable Cognito login); the `admin:` block (including
  `admin.password`) is unchanged. This does not change §Decisions item "Sample-values scope
  confirmed unchanged" in substance (still documents all five keys, still leaves `admin:`
  alone) — only the default disposition (active vs. commented) changes, per task 2.1's revision
  in `tasks.md`.
