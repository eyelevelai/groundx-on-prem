## 1. `cognito.mode` enum widening (schema + mirror) — the end-to-end slice

- [x] 1.1 Add `"local"` to the `cognito.mode` enum in `src/groundx/values.schema.json`
  (`["cognito", "apiKeyOnly"]` → `["cognito", "apiKeyOnly", "local"]`), mirrored byte-identically
  into `helm/values.schema.json`. No template, helper, or render change — the existing
  `groundx.cognito.mode` helper and the `mode: {{ include "groundx.cognito.mode" . | quote }}`
  render already pass any accepted string value through verbatim.
  check: helm template gx src/groundx -n eyelevel -f src/groundx/values/minikube/values.yaml --set cognito.mode=local >/dev/null 2>&1 && helm template gx helm -n eyelevel -f helm/values/minikube/values.yaml --set cognito.mode=local >/dev/null 2>&1 && diff -q src/groundx/values.schema.json helm/values.schema.json

- [x] 1.2 An unrecognized `cognito.mode` value (anything other than `cognito`/`apiKeyOnly`/`local`)
  stays rejected at schema-validation time, on both chart surfaces.
  check: ! helm template gx src/groundx -n eyelevel -f src/groundx/values/minikube/values.yaml --set cognito.mode=bogus >/dev/null 2>&1 && ! helm template gx helm -n eyelevel -f helm/values/minikube/values.yaml --set cognito.mode=bogus >/dev/null 2>&1

- [x] 1.3 The two existing accepted values (`cognito`, `apiKeyOnly`) render unchanged, and an
  install that never sets `cognito.mode` still renders no `cognito:` block.
  check: test "$(helm template gx src/groundx -n eyelevel -f src/groundx/values/minikube/values.yaml --set cognito.mode=cognito --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -c '^    cognito:$')" = "1" && test "$(helm template gx src/groundx -n eyelevel -f src/groundx/values/minikube/values.yaml --set cognito.mode=apiKeyOnly --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -c '^    cognito:$')" = "1" && test "$(helm template gx src/groundx -n eyelevel -f src/groundx/values/minikube/values.yaml --show-only templates/resources/config-yaml.yaml 2>/dev/null | grep -c cognito)" = "0"

## 2. Chart tests (`resources_test.yaml`)

- [x] 2.1 Add a helm-unittest case proving `cognito.mode: local` renders `mode: "local"` into the
  deployed `config.yaml` (`config-yaml-map`), and a second case proving that leaving
  `cognito.mode` unset still renders no `cognito` block — the widening leaves the existing
  default unaffected. Both cases assert with `matchRegex`/`notMatchRegex`, so
  `src/groundx/tests/__snapshot__/resources_test.yaml.snap` needs **no edit at all** for this
  change — confirmed by running the suite without `-u` and observing zero diff against the
  committed snapshot afterward.
  check: helm unittest -f 'tests/resources_test.yaml' src/groundx

## 3. Chart-contract documentation

- [x] 3.1 Document `cognito.mode: local` in `src/groundx/README.md`'s parameter table (+ the
  `helm/README.md` mirror), and add a `## Optional: local` section to `docs/on-prem-identity.md`
  describing the render, that it requires a cashbot-go image that supports it, and the
  roll-forward-not-back rollback note.
  check: grep -q 'cognito.mode' src/groundx/README.md && grep -q 'cognito.mode' helm/README.md && grep -q '^## Optional: `local`$' docs/on-prem-identity.md && grep -qi 'roll forward, not back' docs/on-prem-identity.md

## Notes

- **Validator gate:** `.build/bin/validate-helm.sh` is this repo's full local gate (lint + `helm
  unittest` snapshot tests + dual-surface render checks) and must pass before merge, in addition
  to the task-level checks above. It needs the `helm-unittest` plugin and `yq` (mikefarah v4) —
  see `AGENTS.md` "How to run and test".
- **`helm unittest` footgun (observed during this change, not caused by it):** an invocation of
  `helm unittest` against `src/groundx` that fails partway (e.g. a missing OCR credentials
  fixture) silently rewrites `src/groundx/tests/__snapshot__/*.snap` even without `-u`, dropping
  the snapshots for the tests it could not render. Always generate the OCR credentials fixture
  (or run `.build/bin/validate-helm.sh`, which does this and cleans up) before invoking `helm
  unittest` directly, and `git diff --stat` the `__snapshot__/` tree afterward — a non-empty diff
  when your change added no `matchSnapshot` assertions means the run corrupted the file; `git
  checkout -- <path>` to recover.
- **No template, helper, or Kubernetes-object change** — this is a pure schema-enum widening of
  an already-shipped (GX-20) render surface. No new resource, no migration, no rollout ordering
  constraint.
- **No database migration** — this change touches only the chart's values schema, chart tests,
  and documentation.
- **Cross-service coordination:** this repo's tasks are consumer-only. The `local` value's runtime
  behavior lives entirely in cashbot-go (GX-53, phase 2 of GX-20); no coordination task belongs in
  this file. See the workspace-level change folder for cross-service tracking, if any.
