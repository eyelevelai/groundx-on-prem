## Why

GX-20's decided direction is configurable Cognito (opt-in) plus a durable API-key-only default,
gated by `cognito.mode` (`cognito` | `apiKeyOnly`). cashbot-go (the producer) already implements
this — `config.Cognito{Mode, ClientID, ClientSecret, PoolID, Region}` is unmarshalled from the
single `config.yaml` file every `server/*` binary loads, and `Cognito.Validate()` fails startup
fast when `mode: cognito` is set with any of `clientId`/`clientSecret`/`poolId`/`region` missing
(`cashbot-go` `pkg/config/types.go:132-155`, `pkg/config/api.go:17`, committed `d7bf042`,
FINALIZED in `contract.md`). `groundx-on-prem` renders none of this today: `cognito` does not
appear anywhere in the chart, so an operator has no `values.yaml` surface to opt into
`mode: cognito`, and the chart cannot deliver `clientId`/`clientSecret`/`poolId`/`region` even
though cashbot-go now reads for them. Because an absent/unset `cognito.mode` is cashbot-go's own
safe default (`apiKeyOnly`), every existing on-prem install stays correct on upgrade with zero
chart change — but the chart still needs the plumbing before any install can choose Cognito.

## What Changes

- Add a `cognito:` block (`mode`, `clientId`, `clientSecret`, `poolId`, `region`) to the ConfigMap*
  render for cashbot-go's `config.yaml` — `src/groundx/templates/resources/config-yaml.yaml` —
  following the existing conditional `admin:` block pattern (`:100-118`): each key renders only
  when its value is non-empty, and the whole block renders only when at least one key is set.
  Do **not** render `cognito.adminPassword` (Cloud-only per the FINALIZED contract) and do **not**
  touch or remove the existing top-level `admin.password` key.
- Add `groundx.cognito.*` accessor helpers to `src/groundx/templates/_helpers/main.tpl`, beside
  the existing `groundx.admin.*` helpers (`:5-23`).
- **Mirror both changes byte-identically** into `helm/templates/resources/config-yaml.yaml` and
  `helm/templates/_helpers/main.tpl` (manual mirror, no regen guard — verified with `diff -q`).
- Add a `cognito` object to `src/groundx/values.schema.json` (`mode`, `clientId`, `clientSecret`,
  `poolId`, `region`; `additionalProperties: false`, matching the existing `admin` block's
  shape at `:27-37`) and document the new keys in `sample.values.yaml` (`admin.password` stays,
  per the ticket's assignee decision — unchanged).
- Document the on-prem identity story in `docs/`: default `apiKeyOnly` (durable local
  API-key/customer provisioning; cashbot-go rejects human-identity routes under this mode), the
  optional `mode: cognito` path and its required keys, and the explicit air-gapped answer
  (`apiKeyOnly` — `mode: cognito` requires reaching AWS Cognito, which an air-gapped cluster
  cannot do).

*`cognito.clientSecret` still satisfies the FINALIZED contract's "delivered via a K8s Secret,
never the ConfigMap" requirement without a new resource: `config-yaml-map` (the resource this
template renders) has rendered as `kind: Secret`, not `ConfigMap`, since GX-17
(`openspec/changes/gx-17-config-maps-as-secrets`, `src/groundx/templates/resources/config-yaml.yaml:75-77`).
cashbot-go loads `Cognito` by unmarshalling that one mounted file — there is no env-var or
secondary-file override in `pkg/config/api.go` — so a value split into a second, separate Secret
resource could not reach cashbot-go's config loader without a new merge mechanism the ticket does
not call for. Adding `clientSecret` to this already-Secret-kind resource is the mechanism that
satisfies the contract; a separate net-new Secret template is not needed and is not proposed.

No separate top-level `identity.mode` key is introduced: the FINALIZED contract's confirmed shape
nests the mode selector at `cognito.mode` (`config.Cognito.Mode`, `yaml:"mode"`, inside the
existing `cognito:` block cashbot-go already loads as `config.API.Cognito`) — the earlier
"`identity: mode: …`" phrasing from planning discussion predates the producer's implementation and
is superseded by it.

## Capabilities

### New Capabilities
- `on-prem-identity-config`: the chart-rendered `cognito:` configuration block
  (`mode`/`clientId`/`clientSecret`/`poolId`/`region`) that cashbot-go's `server/*` binaries
  consume to select `apiKeyOnly` (default, no chart change required) vs `cognito` identity mode —
  covering the `config.yaml` render, the `values.schema.json` contract, `sample.values.yaml`
  documentation, and the on-prem identity-story doc.

### Modified Capabilities
(none — no existing capability's requirements change. The `config.yaml` render gains a new,
independently-gated conditional block; every currently-rendered key and behavior is unaffected.)

## Impact

**Affected code:**
- `src/groundx/templates/resources/config-yaml.yaml` + mirror `helm/templates/resources/config-yaml.yaml`
- `src/groundx/templates/_helpers/main.tpl` + mirror `helm/templates/_helpers/main.tpl`
- `src/groundx/values.schema.json`
- `sample.values.yaml`
- `docs/` (new identity-story doc)

**Environments / blast radius:** every environment that redeploys this chart version — dev,
staging, prod, and any customer on-prem install — re-renders `config-yaml-map` (now also carrying
the new, empty-by-default `cognito:` block) on upgrade; the existing `admin:` block and every
other currently-rendered key are untouched. Only an install that explicitly sets
`cognito.mode: cognito` in its own `values.yaml` changes cashbot-go's runtime identity behavior;
every install that does not set it renders no `cognito:` key at all, so cashbot-go's own
`apiKeyOnly` default applies exactly as it does today. No new Kubernetes resource kind, no new
Secret object, no data-store schema or migration in this repo (cashbot-go's own MySQL usage for
`apiKeyOnly` customer/API-key rows is out of this proposal's scope).

**Rollback/rollforward:** `helm rollback` to the prior chart version stops rendering the
`cognito:` block entirely; cashbot-go (deployed independently, pinned to its own image tag) falls
back to its own `apiKeyOnly` default with no data loss, because this proposal introduces no new
persisted on-prem state. Rolling the chart forward without also updating `values.yaml` is
backward-compatible by construction (additive, unset key → `apiKeyOnly`).

**Cross-service dependency:** this proposal consumes the FINALIZED
cashbot-go → groundx-on-prem config-key contract (`pkg/config/types.go:132-155`, committed
`d7bf042`); it makes no change to cashbot-go, `acls.json`, or any SDK — those are explicitly out
of scope per the ticket's per-repo split.

**Open design questions:** none. The identity-mode decision, its scope, and the confirmed
cross-service shape are settled per `.sdd-state/GX-20/source-of-truth.md` and `contract.md`; the
`superpowers:brainstorming` skill is not needed for this change.
