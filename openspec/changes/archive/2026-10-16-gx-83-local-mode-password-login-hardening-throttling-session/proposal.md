## Why

GX-53 adds `cognito.mode: local` (bcrypt passwords in MySQL) for on-prem GroundX. GX-83 hardens that password path in cashbot-go: a 3-failure / 15-minute per-email lock, a uniform response for unknown, disabled and wrong-password attempts, an admin password reset that also ends the customer's MCP sessions, and an API-key option on the MCP authorize page. The behavior changes ship in cashbot-go; operators of this chart need to know the lock exists, how to defend against sustained lockout, what a reset does and does not revoke, and that existing local-mode MCP sessions re-authorize once after the upgrade. `docs/on-prem-identity.md` is the operator-facing identity story, so it must describe the new behavior.

## What Changes

- Rewrite the `local` section of `docs/on-prem-identity.md` to cover:
  - the per-email lock (3 failed attempts, 15-minute lock, the same generic error as any failed login, count cleared by a successful login or an admin reset);
  - a sustained-lockout warning (anyone who knows an email can re-lock it every 15 minutes), with per-source-IP ingress rate limits via `groundx.ingress.annotations` slowing brute-force guessing but no defence against a targeted lockout (accepted residual), and an admin password reset as recovery;
  - the API-key option on the MCP authorize page for customers who have no password yet;
  - a password reset ends that customer's MCP sessions only (after a compromise, disable the account and reset its password);
  - the Redis failover edge case (accepted residual): a Redis failover right after a password reset can lose the revocation-marker advance and revive the MCP sessions that reset ended; a restart or failover resetting the attempt count is only a minor secondary note; plus a Redis eviction recommendation (`noeviction` or `volatile-*`; under `allkeys-*` a revocation marker can be evicted, reviving sessions an earlier reset ended);
  - MCP sign-in on chart installs depends on GX-112, and the sign-up link is hidden on chart installs until then;
  - the requirement for a cashbot-go image that includes GX-83, and the one-line note that after upgrading to such an image existing local-mode MCP sessions must re-authorize once.
- Remove the two stale bullets that PR #123 introduces ("Nothing throttles password attempts" and the MCP sign-in "cannot authorize ... until one is set").
- Add an OpenSpec delta MODIFYING the requirement "The on-prem identity story is documented in `docs/`".
- Not changed: `values.schema.json`, helpers, templates, test snapshots, the `helm/` mirror, `sample.values.yaml`, the chart README, chart version, image tags. No chart behavior changes; docs only.

Rollout and blast radius: documentation only, so no environment redeploys and no stateful resource is touched. Rollback is reverting the docs commit. The documented behavior takes effect only on installs running a cashbot-go image with GX-83, which the doc states explicitly.

Open design questions: none.

Branch note: this change is written against `main`, where the `local` section from PR #123 (branch `gx-53-local-password-login-0.2.7`) does not exist yet. The human decided to write against `main` and reconcile when `main` is merged before PR creation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `on-prem-identity-config`: the requirement "The on-prem identity story is documented in `docs/`" gains the local-mode lock, uniform response, session-revocation scope, API-key fallback, ingress rate-limit guidance, Redis caveats, GX-112 dependency and GX-83 image requirement.

## Impact

- Files: `docs/on-prem-identity.md`; `openspec/specs/on-prem-identity-config` (via delta).
- Cross-service: documents behavior implemented in cashbot-go (GX-83) and mirrored in the groundx-studio-harness `identity-model.md` reference; no runtime contract between repos.
- Out of scope: chart exposure of `mcp.tokenSecret` and the sign-up URL (GX-112); username working as a permanent API key and app-session keys surviving a reset (GX-113).
- PRIVILEGED repo: nothing under `bin/` or `terraform/` is executed or edited.
