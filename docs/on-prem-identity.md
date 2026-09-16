# On-prem identity

An on-prem GroundX install has exactly one identity mode active at a time, selected by
`cognito.mode` in `values.yaml`. The chart renders whatever `cognito.*` keys are set into
cashbot-go's `config.yaml`; cashbot-go's own startup validation decides what the mode requires.

## Default: `apiKeyOnly`

This is the default when the `cognito` section is omitted from `values.yaml` entirely (or its
`mode` key is anything other than the literal `cognito`).

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

## Air-gapped installs

Air-gapped installs must use `apiKeyOnly` — reaching AWS Cognito to validate a login is not
possible without outbound network access to `cognito-idp.<region>.amazonaws.com`, so
`mode: cognito` is not a valid choice for an air-gapped cluster.
