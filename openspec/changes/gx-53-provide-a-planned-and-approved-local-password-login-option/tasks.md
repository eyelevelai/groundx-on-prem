## 1. Render the opt-in `cognito.mode` value (src/groundx — the vertical slice)

- [x] 1.1 Add a `cognito` object (`{ "type": "object", "properties": { "mode": { "type": "string" } },
      "additionalProperties": false }`) to `src/groundx/values.schema.json`; add the
      `groundx.cognito.mode` helper to `src/groundx/templates/_helpers/main.tpl` (alongside
      `groundx.admin.*`, per design Decision 1); render the guarded `cognito: { mode: ... }` block
      into `src/groundx/templates/resources/config-yaml.yaml` between `ai:` and `engines:`, per
      design Decision 4. The acceptance-check stubs for this task are already committed as three new
      `it:` cases appended to `src/groundx/tests/resources_test.yaml` ("local: cognito mode config",
      "cognito: existing enum value still renders", "unset: no cognito block renders") — this task
      is done when all three, and the suite's 813 existing snapshot assertions, pass.
      check: helm unittest src/groundx

## 2. Mirror into `helm/`, byte-identical

- [x] 2.1 Apply the identical `values.schema.json` / `main.tpl` / `config-yaml.yaml` edits from
      task 1.1 to the `helm/` mirror (no `tests/` mirror exists there — see design Decision 6/Risk).
      check: bash -c "helm template check helm --set cognito.mode=local -s templates/resources/config-yaml.yaml | grep -q 'mode: local' && diff src/groundx/values.schema.json helm/values.schema.json && diff src/groundx/templates/resources/config-yaml.yaml helm/templates/resources/config-yaml.yaml && diff src/groundx/templates/_helpers/main.tpl helm/templates/_helpers/main.tpl"

## 3. Operator/customer documentation

- [x] 3.1 Document `cognito.mode` (including `local`) in `src/groundx/README.md`'s values table,
      plus a short section describing the local password-login flow (register → bcrypt-verified
      login → customer body, no token), the admin-mediated password-reset flow (superaccess API
      key, no email/SES), that customers keep using API keys for GroundX API access unchanged under
      every mode, and that `admin.password` stays unused for admin login under every mode (admin
      authenticates by API key only). Mirror the same doc edit into `helm/README.md` (confirmed
      byte-identical to `src/groundx/README.md` today).
      check: n/a — documentation only, no runtime behavior to assert

See workspace `openspec/changes/gx-53-provide-a-planned-and-approved-local-password-login-option/tasks.md`
for cross-service coordination (cashbot-go's `local` enum + password behavior + the
`partner_users.password` migration) and deferred items — none of that is this repo's task.
