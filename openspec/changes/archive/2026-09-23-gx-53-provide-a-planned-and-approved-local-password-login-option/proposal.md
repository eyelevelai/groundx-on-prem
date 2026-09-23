## Why

GX-53 gives on-prem customers a MySQL-backed local password-login option (no Cognito, no login
token, admin-mediated reset) as a third identity mode alongside GX-20's `apiKeyOnly` (default) and
`cognito` modes. cashbot-go's `Cognito.Mode` config field (`pkg/config/types.go`) accepts only
`apiKeyOnly`/`cognito` today, and the on-prem chart renders no `cognito`/identity block into the
deployed RAG `config.yaml` at all — GX-20's chart-side rendering never merged (PR #107 is separate
and unmerged). An operator has no chart-level way to select the new `local` mode once cashbot-go
ships it. This proposal adds that opt-in rendering path now, as the additive Level-1 consumer half
of the cross-service change (cashbot-go is the producer of the `local` enum value and the
password-capable behavior; both are additive and deploy in either order).

## What Changes

- Add a new opt-in `cognito` values block (`values.yaml` + `values.schema.json`) carrying a `mode`
  key accepting `apiKeyOnly` (default/unset) / `cognito` / `local` — mirroring cashbot-go's
  `IdentityMode` enum. This is a **greenfield chart addition**: no `cognito`/identity key exists in
  either file today.
- Render the selected mode into the deployed RAG `config.yaml` ConfigMap
  (`src/groundx/templates/resources/config-yaml.yaml` + a new `groundx.cognito.mode` template
  helper), emitting a `cognito: { mode: ... }` block only when the operator sets a value —
  an unset install renders nothing new and is unaffected.
- Mirror the same template/values/schema changes into `helm/` byte-identical to `src/groundx/`
  (the existing GX-20 manual-mirror rule; there is no regen script).
- Update the helm-unittest golden snapshots (`src/groundx/tests/__snapshot__/*.snap`) for the
  newly-rendered block, regenerated via `helm unittest -u src/groundx` (never hand-edited).
- Add operator/customer documentation (README / values comments) describing: the local
  password-login flow (register → bcrypt-verified login → customer body, no token), the
  admin-mediated password-reset flow (superaccess API key, no email/SES), that customers keep
  using API keys for GroundX API access unchanged under every mode, and that the existing
  `admin.password` values key **stays unused** for login under `local` (admin authenticates by
  API key only, in every mode — flagged so an operator does not mistake it for an admin-login
  credential).

Not in this change (chart side): any new backing service, pod, Deployment, PVC, or reaper; any
change to the `apiKeyOnly` default or `cognito` mode's existing rendering; any DB schema/migration
work (that is cashbot-go's `partner_users.password` column, proposed as data and human-run through
the workspace migration gate — out of this repo entirely); any SDK/OpenAPI change (no such surface
in this chart).

## Capabilities

### New Capabilities
- `local-identity-mode-config`: opt-in chart support for selecting the `local` identity mode —
  the new `cognito.mode` values surface, its rendering into the deployed RAG config, the `src/` ↔
  `helm/` mirror, and the operator/customer documentation of the local password-login,
  admin-mediated reset, and API-key-interaction flow.

### Modified Capabilities
(none — `ingress-backend-routing` and `workspace-managed-data` are the only existing specs and
neither's requirements change)

## Impact

- **Affected files**: `src/groundx/values.yaml`, `src/groundx/values.schema.json`,
  `src/groundx/templates/resources/config-yaml.yaml`, `src/groundx/templates/_helpers/app/groundx.tpl`
  (new helper(s)), `src/groundx/tests/__snapshot__/*.snap` (regenerated), the `helm/` mirror of all
  of the above, and README/operator docs. No `bin/` operator-tooling changes.
- **Blast radius**: additive and opt-in. An install that does not set `cognito.mode` (or sets
  `apiKeyOnly`/`cognito`) renders exactly what it renders today — verified today's chart has no
  `cognito` key to collide with. Only an install that explicitly sets `cognito.mode: local` opts
  into the new rendered block. `values.schema.json` is `additionalProperties: false` on most
  blocks, so the new `cognito` key must be added there or a `local`-mode install's `values.yaml`
  fails validation — schema and template changes ship together.
- **Environments**: dev/staging/prod all carry the change (same chart), but it is inert everywhere
  until an operator opts in per install. No data or stateful-resource impact from this repo: no new
  PVC, no new backing service, no schema/DB change (the nullable `partner_users.password` column is
  cashbot-go's change, gated by the workspace's own DB-migration review/run process, not touched
  here).
- **Rollout**: an operator upgrading to opt into `local` mode redeploys via the existing chart
  upgrade path (config-map change → normal rolling pod restart of the affected GroundX
  deployment(s), no different from any other config-value change this chart already supports).
- **Rollback**: unset `cognito.mode` (or pin the prior chart version). Because the block is
  opt-in and renders nothing when absent, rollback leaves no residual chart-rendered state to
  clean up.
- **Open design questions**: none — the identity-mode value, the no-token/admin-reset behavior,
  and the additive compatibility classification are locked by the ticket's approved plan
  (`source-of-truth.md` "Locked decisions" + "Design constraints"); this proposal's scope is
  the chart-side rendering/values/docs surface only.
