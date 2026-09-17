## 1. `cognito` chart-config surface (schema + render + mirror) — the end-to-end slice

- [x] 1.1 Add a `cognito` object (`mode`, `clientId`, `clientSecret`, `poolId`, `region`; all `type: string`; `additionalProperties: false`, no `adminPassword` property) to `src/groundx/values.schema.json`, matching the existing `admin` block's shape, mirrored byte-identically into `helm/values.schema.json`.
  check: helm template src/groundx -f src/groundx/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito.yaml >/dev/null 2>&1 && helm template helm -f helm/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito.yaml >/dev/null 2>&1 && ! helm template src/groundx -f src/groundx/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito-admin-password-rejected.yaml >/dev/null 2>&1 && ! helm template helm -f helm/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito-admin-password-rejected.yaml >/dev/null 2>&1 && diff -q src/groundx/values.schema.json helm/values.schema.json

- [x] 1.2 Add `groundx.cognito.{mode,clientId,clientSecret,poolId,region}` helpers to `src/groundx/templates/_helpers/main.tpl` (beside `groundx.admin.*`, `:5-23`) and the conditional `cognito:` block to `src/groundx/templates/resources/config-yaml.yaml` — whole-block guard plus one independent per-key guard, copying the existing `admin:` block's structure (`:100-118`) exactly; never emit a `cognito.adminPassword` key or helper. Mirror both files byte-identically into `helm/templates/_helpers/main.tpl` and `helm/templates/resources/config-yaml.yaml`.
  check: test "$(helm template src/groundx -f src/groundx/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito.yaml --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -cE '^      (mode: "cognito"|clientId: "cognito-test-client-id"|clientSecret: "cognito-test-client-secret"|poolId: "us-east-1_TESTPOOL123"|region: "us-east-1")$')" = "5" && test "$(helm template helm -f helm/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito.yaml --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -cE '^      (mode: "cognito"|clientId: "cognito-test-client-id"|clientSecret: "cognito-test-client-secret"|poolId: "us-east-1_TESTPOOL123"|region: "us-east-1")$')" = "5" && test "$(helm template src/groundx -f src/groundx/values/minikube/values.yaml --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -c cognito)" = "0" && test "$(helm template src/groundx -f src/groundx/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito.yaml --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -c 'kind: Secret')" = "1" && diff -q src/groundx/templates/_helpers/main.tpl helm/templates/_helpers/main.tpl && diff -q src/groundx/templates/resources/config-yaml.yaml helm/templates/resources/config-yaml.yaml

- [x] 1.3 (review-fix round 1) Add an `enum: ["cognito", "apiKeyOnly"]` constraint to `cognito.mode` in `src/groundx/values.schema.json`, mirrored byte-identically into `helm/values.schema.json`, so a typo'd `cognito.mode` value is rejected at `helm template`/`helm lint` time instead of silently degrading through cashbot-go's own tolerant-reader fallback. `cognito` stays fully optional — the enum only constrains the value when the key is present. Added `src/groundx/tests/files/values.cognito-bad-mode-rejected.yaml` as the rejection fixture; the existing `values.cognito.yaml` and `values.cognito-admin-password-rejected.yaml` fixtures already use the valid `mode: cognito` and need no change. See `design.md` Amendments for why this supersedes the original "no enum restriction" decision.
  check: ! helm template src/groundx -f src/groundx/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito-bad-mode-rejected.yaml >/dev/null 2>&1 && ! helm template helm -f helm/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito-bad-mode-rejected.yaml >/dev/null 2>&1 && helm template src/groundx -f src/groundx/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito.yaml >/dev/null 2>&1 && helm template helm -f helm/values/minikube/values.yaml -f src/groundx/tests/files/values.cognito.yaml >/dev/null 2>&1 && diff -q src/groundx/values.schema.json helm/values.schema.json

## 2. Chart-contract documentation (`sample.values.yaml`)

- [x] 2.1 (amended in review-fix round 1 — see `design.md` Amendments) Document the `cognito.*` keys in `sample.values.yaml` as a fully commented-out example (`mode`, `clientId`, `clientSecret`, `poolId`, `region`, all five keys shown, prefixed `#`) with a note that uncommenting and filling it enables Cognito login and that omitting/leaving it commented keeps the install on the `apiKeyOnly` default; leave the existing `admin:` block (including `admin.password`) unchanged. A default, unmodified copy of `sample.values.yaml` renders zero active `cognito` keys.
  check: grep -q '^# cognito:' sample.values.yaml && grep -A6 '^# cognito:' sample.values.yaml | grep -q '#\s*mode:' && grep -A6 '^# cognito:' sample.values.yaml | grep -q '#\s*clientId:' && grep -A6 '^# cognito:' sample.values.yaml | grep -q '#\s*clientSecret:' && grep -A6 '^# cognito:' sample.values.yaml | grep -q '#\s*poolId:' && grep -A6 '^# cognito:' sample.values.yaml | grep -q '#\s*region:' && grep -q 'apiKeyOnly' sample.values.yaml && test "$(helm template src/groundx -f src/groundx/values/minikube/values.yaml -f <(grep -v '^groundxKey' sample.values.yaml) --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -c cognito)" = "0"

## 3. On-prem identity story documentation

- [x] 3.1 Write `docs/on-prem-identity.md`: the `apiKeyOnly` default identity behavior, the optional `cognito` mode and its five required keys, and the explicit air-gapped answer (`apiKeyOnly` — `mode: cognito` requires reaching AWS Cognito, which an air-gapped cluster cannot do).
  check: test -f docs/on-prem-identity.md && grep -q 'apiKeyOnly' docs/on-prem-identity.md && grep -qi 'cognito' docs/on-prem-identity.md && grep -qi 'air-gap' docs/on-prem-identity.md

- [x] 3.2 Document that a Cognito-enabled installation must not roll back to a pre-GX-20 chart, because it removes the rendered `cognito:` configuration and disables password authentication; direct recovery to a GX-20-compatible forward fix instead.
  check: grep -q 'MUST NOT.*pre-GX-20' openspec/changes/archive/2026-09-15-gx-20-on-prem-has-no-identity-provider-servergroundx-wires-a-mock/design.md && grep -q 'Do not run.*before GX-20' docs/on-prem-identity.md

## Notes

- **Validator gate:** `.build/bin/validate-helm.sh` is this repo's full local gate (lint + `helm unittest` snapshot tests + dual-surface render checks) and must pass before merge, in addition to the task-level checks above.
- **Cross-service coordination:** this repo's tasks are consumer-only. See the workspace `openspec/changes/gx-20-on-prem-has-no-identity-provider-servergroundx-wires-a-mock/tasks.md` for the cashbot-go (producer) dependency order, the Cloud rollout dependency (pool id/region at deploy time), and hand-off items — none of that is a checkbox in this file.
- **No database migration** — this change touches only chart templates, the values schema, and documentation.

## Amendments

### 2026-09-16 — review-fix round 1

- **G1 (real defect):** `sample.values.yaml` shipped an *active* `cognito:` block (`mode: cognito`
  plus four placeholder values) as the default, so a customer who copied the file unmodified
  landed in `mode: cognito` with placeholder credentials and hit cashbot-go's startup-fatal
  `Cognito.Validate()`. Fixed by commenting out the entire `cognito:` block (task 2.1, revised
  above) so the default copy stays on `apiKeyOnly` with zero active `cognito` keys.
- **F2 (chart-layer typo guard):** added `enum: ["cognito", "apiKeyOnly"]` to `cognito.mode` in
  `values.schema.json` / `helm/values.schema.json` (task 1.3, added above) so a typo'd `mode`
  value is rejected at `helm template`/`helm lint` time instead of silently falling through
  cashbot-go's own tolerant-reader default. This supersedes `design.md`'s original "no enum
  restriction" decision — see `design.md` Amendments for the rationale and why it does not
  narrow the wire contract with cashbot-go.

### 2026-09-16 — documentation amendment (Ben, 2026-09-15 comment 12)

- **Docs-only, no new task.** Added a paragraph to `docs/on-prem-identity.md`'s Cognito section
  and a comment line in `sample.values.yaml`'s commented cognito example noting that
  `mode: cognito` requires AWS credentials reaching the pod via the chart's existing mechanisms
  (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` env vars or an IRSA-enabled
  `serviceAccount.name`) plus `cognito.region`; no schema/template/config-field change. Also
  added a note to `docs/on-prem-identity.md`'s `apiKeyOnly` section confirming the seeded admin
  has superuser authority (`partner_users.status = 'admin'`, the only status for which
  cashbot-go's `AccountType.IsAdmin()` returns `true`). See `design.md` Amendments for the full
  rationale + code citations. Task 2.1 and 3.1's existing checks are unaffected (still pass
  unchanged).
