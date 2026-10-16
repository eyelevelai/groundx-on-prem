# On-prem identity

An on-prem GroundX install has exactly one identity mode active at a time, selected by
`cognito.mode` in `values.yaml`. The chart renders whatever `cognito.*` keys are set into
cashbot-go's `config.yaml`; cashbot-go's own startup validation decides what the mode requires.

## Default: `apiKeyOnly`

This is the default when the `cognito` section is omitted from `values.yaml` entirely, or `mode`
is set to `apiKeyOnly`. The chart's `values.schema.json` accepts only `cognito` or `apiKeyOnly`
for `cognito.mode`; any other value is rejected at render time.

- Identity is limited to the seeded admin API key (`admin.apiKey`) plus durable, DB-backed
  customer/API-key rows created by the admin — no password login.
- Every human-identity route (login, register, password reset/confirm, and every Basic-Auth
  route) is rejected by a code guard in cashbot-go.
- No route on an `apiKeyOnly` install can return a test/mock token.
- The seeded admin has superuser/admin authority, not merely elevated API access: cashbot-go
  creates its `partner_users` row with `status = 'admin'`, the only status for which
  `AccountType.IsAdmin()` returns `true`, which is what lets it provision durable customers and
  their API keys.

## Optional: `cognito`

Set `cognito.mode: cognito` plus all four of the following keys:

```yaml
cognito:
  mode: cognito
  clientId: "<cognito-app-client-id>"
  clientSecret: "<cognito-app-client-secret>"
  poolId: "<cognito-user-pool-id>"
  region: "<aws-region>"
```

- `clientId`, `clientSecret`, `poolId`, and `region` are all required once `mode: cognito` is
  set. `clientSecret` is delivered to the workload through the existing `config-yaml-map` Secret,
  not a plaintext ConfigMap.
- `mode: cognito` also requires AWS credentials reaching the pod so cashbot-go's Cognito API
  calls succeed — this is **not** a new chart value. Supply them the standard way the chart
  already supports: either standard AWS environment variables on the pods
  (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, as documented for file storage in
  `values.yaml`) or an IRSA-enabled Kubernetes service account via `serviceAccount.name` (see
  `values/values.aws.services.yaml`; the golang app pods already render `serviceAccountName`
  from this value). `cognito.region` must be set either way. Without valid AWS credentials
  reaching the pod, Cognito calls fail.
- Missing any of the four keys while `mode: cognito` is set is a cashbot-go **startup fatal
  error** — the chart itself does not validate completeness, and there is no silent fallback to
  `apiKeyOnly` or to a mock client.
- `cognito.adminPassword` is not a supported chart key (rejected by `values.schema.json`); it has
  no rendering path on-prem and is unrelated to the separate, unchanged `admin.password` key.

## Optional: `local`

`local` mode lets customers sign in to GroundX and the MCP authorize page with an email and
password stored in your own database, with no external identity provider. The behavior below
applies only to a cashbot-go image that includes GX-83; an older image does not have it.
`local` mode also needs the chart release that adds `cognito.mode: local` (GX-53, PR #123).

### Login lockout

- Three failed password attempts within 15 minutes locks that email for 15 minutes, counted from
  the third failure.
- A locked email and a wrong password get the same generic error. The response does not reveal
  whether an email exists.
- A successful login or an admin password reset clears the failure count.
- A Redis restart or failover can reset the failure count. This only gives an attacker a fresh set
  of attempts and is not a security boundary change.

### Sustained lockout

Anyone who knows a customer's email can keep that account locked by repeatedly failing logins.
A per-source-IP rate limit at the ingress slows brute-force guessing and bcrypt load. Set the
limit annotations for your ingress controller under `groundx.ingress.annotations`, which apply
to every route of the API Ingress. The chart has no defence against a targeted lockout of a
known email; this is an accepted residual. Recovery for a locked customer is an admin password
reset, which clears the lock.

### MCP sign-in

- The MCP authorize page has an `Or use a GroundX API key` field below the email and password
  fields, for customers who have no password.
- MCP sign-in on chart installs needs GX-112. Until that lands, the sign-up link is hidden on
  chart installs. This chart does not yet expose the values it needs.

### Password reset and MCP sessions

An admin password reset ends that customer's MCP sessions only. Their API keys and app sessions
are not touched. After a suspected compromise, disable the account. Deleting API keys alone does not help,
because the username itself still works as a credential (GX-113).

### Redis

MCP session revocation relies on Redis.

- Accepted edge case: a Redis failover right after a password reset can revive the MCP sessions
  that reset ended.
- Set the Redis `maxmemory-policy` to `noeviction` or a `volatile-*` policy. Under an `allkeys-*`
  policy the reset marker can be evicted, which revives MCP sessions that an earlier reset ended.
  Future resets still work.
- The chart has no setting for the eviction policy. Check it on the running Redis with
  `redis-cli CONFIG GET maxmemory-policy`; this also applies to customer-managed Redis.

### Upgrading

After upgrading to a GX-83 image, existing local-mode MCP sessions must re-authorize once.
Sessions issued before GX-83 have no owning customer and are rejected.

## Rollback

Do not run `helm rollback` to a chart version before GX-20 for an installation using
`mode: cognito`. The older chart removes the rendered `cognito:` configuration; when the pod
restarts, cashbot-go falls back to `apiKeyOnly` and password authentication stops working. There
is no Cognito-preserving rollback to a chart without this configuration surface. Use a forward
fix on a GX-20-compatible chart/image instead. Ordinary Helm rollback remains appropriate only
for installations that did not enable Cognito.

## Air-gapped installs

Air-gapped installs must use `apiKeyOnly` — reaching AWS Cognito to validate a login is not
possible without outbound network access to `cognito-idp.<region>.amazonaws.com`, so
`mode: cognito` is not a valid choice for an air-gapped cluster.
