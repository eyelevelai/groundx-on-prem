## 1. Lock and uniform response (first shippable slice)

- [x] 1.1 Add a `local` section to `docs/on-prem-identity.md` stating three failed attempts lock the email for 15 minutes, locked and failed attempts get the same generic error, and success or an admin reset clears the count
  check: grep -q 'locks that email for 15 minutes' docs/on-prem-identity.md

## 2. Operator guidance

- [x] 2.1 Add the sustained-lockout warning with per-source-IP ingress rate limits via `groundx.ingress.annotations` as slowing brute-force guessing but no defence against a targeted lockout (accepted residual), and admin reset as recovery
  check: grep -q 'Sustained lockout' docs/on-prem-identity.md && grep -q 'groundx.ingress.annotations' docs/on-prem-identity.md
- [x] 2.2 Document the MCP authorize-page API-key option for customers with no password
  check: grep -q 'Or use a GroundX API key' docs/on-prem-identity.md
- [x] 2.3 State that a reset ends that customer's MCP sessions only, and that after a compromise the operator disables the account and resets its password
  check: grep -q 'MCP sessions only' docs/on-prem-identity.md

## 3. Redis, chart dependency and upgrade notes

- [x] 3.1 Document the Redis failover edge case and recommend `noeviction` or `volatile-*` (marker can be evicted under `allkeys-*`; customer-managed Redis policy is unknown)
  check: grep -q 'noeviction' docs/on-prem-identity.md && grep -q 'allkeys-' docs/on-prem-identity.md
- [x] 3.2 State that MCP sign-in on chart installs needs GX-112 and the sign-up link is hidden until then, without claiming chart support
  check: grep -q 'GX-112' docs/on-prem-identity.md
- [x] 3.3 State the cashbot-go GX-83 image requirement and that existing local-mode MCP sessions must re-authorize once after upgrading
  check: grep -q 'GX-83 image' docs/on-prem-identity.md && grep -q 'must re-authorize once' docs/on-prem-identity.md

## 4. Stale text and whole-change validation

- [x] 4.1 Ensure the stale pre-GX-83 statements are absent, and the removed wording is absent, and the `apiKeyOnly`, `cognito` and rollback sections are unchanged
  check: ! grep -qE 'Nothing throttles password attempts|cannot authorize|Sign in with an API key|are the defence|cannot tell whether|also delete the' docs/on-prem-identity.md && grep -q 'locks that email for 15 minutes' docs/on-prem-identity.md && grep -q '^## Air-gapped installs' docs/on-prem-identity.md && grep -q '^## Rollback' docs/on-prem-identity.md
- [x] 4.2 Run `openspec validate --specs`
  check: grep -q 'must re-authorize once' docs/on-prem-identity.md && openspec validate --specs

See workspace `openspec/changes/gx-83-local-mode-password-login-hardening-throttling-session/tasks.md` for cross-service coordination and deferred items.
