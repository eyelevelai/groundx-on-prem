# On-prem identity

An on-prem GroundX install has exactly one identity mode active at a time, selected by
`cognito.mode` in `values.yaml`. The chart renders whatever `cognito.*` keys are set into
cashbot-go's `config.yaml`; cashbot-go's own startup validation decides what the mode requires.

## Default: `apiKeyOnly`

This is the default when the `cognito` section is omitted from `values.yaml` entirely, or `mode`
is set to `apiKeyOnly`. The chart's `values.schema.json` accepts only `cognito`, `apiKeyOnly`, or
`local` for `cognito.mode`; any other value is rejected at render time.

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

Set `cognito.mode: local`:

```yaml
cognito:
  mode: local
```

- The chart renders `mode: "local"` into `config.yaml` with no other `cognito.*` key required —
  the render is the same single-key `cognito.mode` pass-through the `apiKeyOnly` default uses.
- `local` requires a cashbot-go image that supports it; the chart itself does not validate the
  image version and does not implement the local password-login behavior — that is entirely
  cashbot-go's runtime concern.

## Rollback

Do not run `helm rollback` to a chart version before GX-20 for an installation using
`mode: cognito`. The older chart removes the rendered `cognito:` configuration; when the pod
restarts, cashbot-go falls back to `apiKeyOnly` and password authentication stops working. There
is no Cognito-preserving rollback to a chart without this configuration surface. Use a forward
fix on a GX-20-compatible chart/image instead. Ordinary Helm rollback remains appropriate only
for installations that did not enable Cognito.

The same applies to `mode: local`: a chart version before this `local` value was added to the
schema rejects `cognito.mode: local` at render/validation time rather than silently falling back
— roll forward, not back, for an install using `local`.

## Air-gapped installs

Air-gapped installs can use `apiKeyOnly` or `local`. Both authenticate entirely within the
cluster — `local` verifies passwords against bcrypt hashes stored in MySQL and makes no outbound
calls. Only `mode: cognito` is unavailable: validating a login against AWS Cognito needs outbound
network access to `cognito-idp.<region>.amazonaws.com`, so it is not a valid choice for an
air-gapped cluster.
