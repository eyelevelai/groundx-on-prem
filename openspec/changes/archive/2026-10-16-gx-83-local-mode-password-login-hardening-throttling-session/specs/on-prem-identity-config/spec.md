## MODIFIED Requirements

### Requirement: The on-prem identity story is documented in `docs/`

`docs/on-prem-identity.md` SHALL state the default `apiKeyOnly` identity behavior, the optional `cognito` mode and its required keys, and the explicit air-gapped answer (`mode: cognito` requires reaching AWS Cognito, which an air-gapped cluster cannot do; air-gapped installs use `apiKeyOnly`, or `local` for password login subject to the GX-53 chart release). It SHALL also document the `local` mode password path as hardened by GX-83, covering:

- the per-email lock: three failed password attempts lock that email for 15 minutes, a locked or failed attempt returns the same generic error as any other failed login, and a successful login or an admin password reset clears the count;
- a sustained-lockout warning: anyone who knows an email can re-lock it every 15 minutes; per-source-IP ingress rate limits set through `groundx.ingress.annotations` slow brute-force guessing but are no defence against a targeted lockout of a known email (accepted residual), and an admin password reset is the recovery;
- the API-key option on the MCP authorize page, for customers who have no password yet;
- the scope of a password reset: it ends that customer's MCP sessions only, and after a compromise the operator must disable the account and reset its password (disabling can take up to an hour to reach cached credentials), since deleting API keys alone does not help (the username still works as a credential, GX-113);
- Redis behaviour: a failover right after a reset can revive MCP sessions that reset ended (accepted residual), and a Redis `maxmemory-policy` of `noeviction` or `volatile-*` is recommended because under `allkeys-*` a revocation marker can be evicted, and the operator checks it with `redis-cli CONFIG GET maxmemory-policy` since the chart has no setting for it;
- MCP sign-in on chart installs depends on GX-112, and the sign-up link is hidden on chart installs until then;
- the requirement for a cashbot-go image that includes GX-83, and a one-line note that after upgrading to such an image existing local-mode MCP sessions must re-authorize once.

The document SHALL NOT contain the pre-GX-83 statements that nothing throttles password attempts or that MCP sign-in cannot authorize a customer until a password is set.

#### Scenario: The identity-story doc covers both modes and the air-gapped answer (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** `docs/on-prem-identity.md` is inspected
- **THEN** it states the `apiKeyOnly` default, documents the `cognito.*` keys required to opt into `mode: cognito`, and explicitly states that air-gapped installs cannot use `mode: cognito` and use `apiKeyOnly` or `local`

#### Scenario: The doc describes the lock and the uniform response (polarity: reject before state)

- **GIVEN** this change is applied
- **WHEN** the `local` section of `docs/on-prem-identity.md` is inspected
- **THEN** it states that three failed attempts lock the email for 15 minutes and that a locked attempt gets the same generic error as any failed login
- **AND THEN** it does not state or imply that a locked attempt is counted, extends the lock, or reveals whether the email exists

#### Scenario: The doc warns about sustained lockout and names the defence (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it warns that anyone who knows an email can re-lock it every 15 minutes, names per-source-IP ingress rate limits via `groundx.ingress.annotations` as slowing brute-force guessing but no defence against a targeted lockout (accepted residual), and names an admin password reset as the recovery

#### Scenario: The doc limits what a reset revokes (polarity: finalize failure — the reset does not end API-key access)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it states a reset ends that customer's MCP sessions only and tells the operator to disable the account and reset its password after a compromise, noting disabling can take up to an hour to take effect, since deleting API keys alone does not help (GX-113)
- **AND THEN** it does not claim a reset revokes API keys or app sessions

#### Scenario: The doc states the Redis caveats (polarity: finalize success)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it describes the failover edge case (sessions ended by a reset can be revived) and recommends `noeviction` or `volatile-*`, stating that `allkeys-*` can evict the revocation marker

#### Scenario: The doc does not claim chart support for MCP sign-in (polarity: skip unrelated repair path)

- **GIVEN** this change is applied
- **WHEN** the `local` section is inspected
- **THEN** it states MCP sign-in on chart installs needs GX-112 and the sign-up link is hidden until then
- **AND THEN** it does not claim the chart exposes an MCP token secret or a sign-up URL value

#### Scenario: The doc states the image requirement and the one-time re-authorization (backward compatibility — cross-service touchpoint)

- **GIVEN** an install running a cashbot-go image from before GX-83, or one on `apiKeyOnly` or `cognito` mode
- **WHEN** the operator reads `docs/on-prem-identity.md`
- **THEN** the doc states the `local` lock and revocation behavior needs a cashbot-go image that includes GX-83, and that after upgrading to such an image existing local-mode MCP sessions must re-authorize once
- **AND THEN** the `apiKeyOnly`, `cognito` and rollback sections are unchanged

#### Scenario: Stale pre-GX-83 statements are absent (polarity: reject before state)

- **GIVEN** this change is applied
- **WHEN** `docs/on-prem-identity.md` is searched for "Nothing throttles password attempts" and for the statement that MCP sign-in cannot authorize until a password is set
- **THEN** neither is found
