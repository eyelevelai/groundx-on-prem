## Why

GX-20 already gave this chart a `cognito` config surface (schema block, `groundx.cognito.mode`
render helper, and a guarded `cognito:` block in `config-yaml.yaml`) that renders whatever string
value `cognito.mode` is set to. `values.schema.json` currently restricts that value to
`["cognito", "apiKeyOnly"]`, so an operator cannot select cashbot-go's new local password-login
identity mode (GX-53, phase 2 of GX-20) — `helm template`/`helm lint`/`helm upgrade` reject
`cognito.mode: local` at schema validation before the render is ever reached.

## What Changes

- Add `"local"` to the `cognito.mode` enum in `src/groundx/values.schema.json`
  (`["cognito", "apiKeyOnly"]` → `["cognito", "apiKeyOnly", "local"]`), mirrored byte-identically
  into `helm/values.schema.json`. No template, helper, or render change — the existing
  `groundx.cognito.mode` helper and the `mode: {{ include "groundx.cognito.mode" . | quote }}`
  render already pass any accepted string value through verbatim.
- Add a helm-unittest assertion proving `cognito.mode: local` renders `mode: "local"` into the
  deployed `config.yaml`, and that leaving `cognito.mode` unset still renders no `cognito` key.
- Document `cognito.mode: local` in `src/groundx/README.md` (+ `helm/README.md` mirror) and
  `docs/on-prem-identity.md`, including that it requires a cashbot-go image that supports it.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `on-prem-identity-config`: the `cognito.mode` requirement (originally scoped to `cognito`/
  `apiKeyOnly` by GX-20) now also accepts `local`; no change to the render mechanism, the guard
  structure, or the four Cognito-specific keys (`clientId`/`clientSecret`/`poolId`/`region`),
  which stay irrelevant to `local`.

## Impact

- `src/groundx/values.schema.json`, `helm/values.schema.json` — one-line enum change, mirrored.
- `src/groundx/tests/resources_test.yaml` — two new helm-unittest cases.
- `src/groundx/README.md`, `helm/README.md`, `docs/on-prem-identity.md` — documentation.
- No template, helper, or Kubernetes-object change. No new resource, no migration, no rollout
  ordering constraint beyond the existing GX-20 one (chart-side change is additive and consumed
  by a cashbot-go image that already accepts `local`; an install that never sets `cognito.mode`
  is byte-for-byte unaffected). Environments: dev/staging/prod on-prem chart consumers who choose
  to opt into `cognito.mode: local` — no stateful-resource impact, no data migration.
- Rollback: rolling back to a chart version before this change causes `cognito.mode: local` to
  be rejected at schema-validation time (a `helm template`/`helm upgrade` failure, not a silent
  runtime fallback) for any install that had set it — roll forward rather than back for those
  installs; every other install is unaffected either way.
- Open design questions: none — the render mechanism and guard structure are unchanged; this is
  a pure enum-widening change with no facilitated design decision to brainstorm.
