## Goals / Non-Goals

Goals: make `docs/on-prem-identity.md` the accurate operator-facing description of the GX-83 `local` password path (see proposal.md and the approved cross-service plan). Non-goals: any chart, schema, helper, template, snapshot, `helm/` mirror, `sample.values.yaml`, README, version or image-tag change; the chart value for `mcp.tokenSecret` and the sign-up URL (GX-112); username-as-permanent-API-key and app-session keys surviving a reset (GX-113).

## Decisions

### Documentation-only, no chart behavior

The behavior ships in cashbot-go. This repo only documents it, so there is no rollout ordering, no stateful resource touched and no redeploy. Rollback is reverting the docs commit. The doc states the behavior applies only on a cashbot-go image that includes GX-83. No ADR is warranted: no architectural decision is made here.

### Write against `main`; the `local` section is new text

On `main`, `docs/on-prem-identity.md` has no `local` section (it exists only on `gx-53-local-password-login-0.2.7`, PR #123). The human decided to write against `main`: this change adds a `local` section with the GX-83 content and does not carry PR #123's two stale bullets ("Nothing throttles password attempts", "cannot authorize ... until one is set"). The section is reconciled with PR #123's text when `main` is merged before PR creation.

### Document the lock as operators experience it

State: three failed attempts lock the email for 15 minutes; locked and failed attempts get the same generic error; success or admin reset clears the count. Do not document Redis keys, Lua or counting internals; those live in cashbot-go. The sustained-lockout warning is stated plainly with its defence (per-source-IP ingress rate limits via `groundx.ingress.annotations`, which the chart renders onto the Ingress; `templates/resources/ingress.yaml`) and recovery (admin reset).

### Reset scope is stated narrowly

A reset ends that customer's MCP sessions only. API keys and app sessions are untouched, so after a compromise the operator also deletes the API keys or disables the account. The doc must not say a reset revokes more.

### Redis caveats are stated as accepted residuals with a recommendation

Failover right after a reset can lose the revocation advance and revive sessions the reset ended. Recommend `maxmemory-policy` `noeviction` or `volatile-*`; under `allkeys-*` the marker can be evicted, reviving sessions an earlier reset ended but never breaking future resets. The chart's Redis policy comes from the image's `/etc/redis.conf`, which `groundx.cache.confContent` includes (`src/groundx/templates/_helpers/services/cache.tpl:242`); for customer-managed Redis it is unknown, so the doc says to check it. A restart or failover resetting the attempt count is a minor secondary note.

### GX-112 dependency is not papered over

MCP sign-in on chart installs needs GX-112 and the sign-up link is hidden on chart installs until then. The doc must not claim the chart exposes either value.

### One-time re-authorization

After upgrading to a GX-83 image, existing local-mode MCP sessions must re-authorize once (pre-GX-83 records have no owning customer and are rejected). One line in the doc.

### Verification is grep-anchored

Each task's `check:` is a `grep` against `docs/on-prem-identity.md` for a literal anchor phrase that the implementation must write verbatim and that is absent on today's text, so the RED baseline fails. Anchors: `locks that email for 15 minutes`, `Sustained lockout`, `groundx.ingress.annotations`, `Sign in with an API key`, `MCP sessions only`, `noeviction`, `GX-112`, `GX-83 image`, `must re-authorize once`. Producer contract shapes are not applicable (INDEPENDENT, no runtime contract).

## Risks / Trade-offs

- Grep anchors prove the wording is present, not that it is accurate; accuracy is checked at review against the plan.
- Reconciling with PR #123 at merge may conflict textually in the `local` section; accepted by the human decision above.
- The pre-push gate (`.build/bin/validate-helm.sh`) runs at hand-off by the orchestrator; nothing under `bin/` or `terraform/` is executed or edited.
