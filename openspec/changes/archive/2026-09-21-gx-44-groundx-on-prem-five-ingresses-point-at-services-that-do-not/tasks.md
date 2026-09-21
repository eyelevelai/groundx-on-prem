## 1. Backend derivation names the rendered `-api` Service (both shapes, both surfaces)

- [x] 1.1 In `src/groundx/templates/resources/ingress.yaml`, add `$backend` derived from
      `groundx.<entry>.serviceName` beside the existing `$port` derivation, and use it (not
      `$name`) at the `networking.k8s.io/v1` backend site (`service.name`). `metadata.name` keeps
      using `$name`. Regenerate `src/groundx/tests/__snapshot__/workspace_test.yaml.snap`
      (`helm unittest -u src/groundx -f 'tests/workspace_test.yaml'`) so the pathless-v1 snapshot
      reflects the corrected backend.
      check: helm unittest src/groundx -f 'tests/workspace_test.yaml'
- [x] 1.2 Use the same `$backend` at the legacy shape's backend site (`serviceName`).
      check: helm unittest src/groundx -f 'tests/ingress_test.yaml'
- [x] 1.3 Mirror `resources/ingress.yaml` into `helm/` (byte-identical to `src/groundx/`) and add
      the two-surface render assertion to `.build/bin/validate-helm.sh` beside the existing
      `extract-agent` image-settings loop, rendering `tests/files/values.phoenix.yaml` against
      both `src/groundx` and `helm` and asserting the `extract-api`/`summary-api` backends.
      check: bash -c 'for c in src/groundx helm; do o=$(helm template phoenix-check "$c" -f src/groundx/tests/files/values.phoenix.yaml -s templates/resources/ingress.yaml) || exit 1; echo "$o" | grep -q "name: extract-api" || exit 1; echo "$o" | grep -q "name: summary-api" || exit 1; done'

## 2. A pathless API Ingress fails when its Service is not created (D4)

- [x] 2.1 In `src/groundx/templates/_helpers/app/ingress.tpl`'s `groundx.app.ingress` entry loop,
      restricted to the five `*.api` entries and only when the entry's ingress data carries no
      non-empty `paths`, call `include (printf "groundx.%s.create" $entry) $` and `fail` with
      `"<entry>.ingress is enabled but <entry> is not created; enable <entry> or remove the
      ingress"` when it returns `false`. Custom `paths` and the two non-API entries are untouched.
      check: helm unittest src/groundx -f 'tests/ingress-guard_test.yaml'
- [x] 2.2 Mirror `_helpers/app/ingress.tpl` into `helm/` and add one
      `expect_helm_template_failure`-style call inside `.build/bin/validate-helm.sh`'s existing
      both-surface loop (`for chart in src/groundx helm`), rendering
      `values/extract/values.yaml` with `--set workspace.api.ingress.enabled=true` and asserting
      the render fails on both surfaces (a verified trigger — `workspace.api.create` is false
      under that values file).
      check: bash -c 'for c in src/groundx helm; do helm template invalid-workspace-ingress "$c" -f src/groundx/values/extract/values.yaml --set workspace.api.ingress.enabled=true >/dev/null 2>&1 && exit 1; done; exit 0'

## 3. Full gate

- [x] 3.1 Run the repo's CI-parity validator end to end (lint, unit tests, snapshot guard,
      both-surface render checks) and confirm it is clean.
      check: bash .build/bin/validate-helm.sh

## Deferred follow-ups

Split out of this ticket at the brainstorm gate (see `proposal.md` "Explicitly out of scope");
each needs a Linear ticket filed before the workspace change record is archived — see the
workspace `openspec/changes/gx-44-.../tasks.md` "Deferred follow-ups" for the full list (the file
Ingress never rendering, the unconditional `ai.eyelevelSearch.baseURL`, and the `src/groundx` vs
`helm/` mirror drift on the `origin/0.2.7` line). No cross-service coordination applies —
groundx-on-prem is the only affected repo for this change.

- The D4 not-created guard is gated on `hasSuffix ".api" $svc`, so it does not cover the `groundx`
  or `layoutWebhook` pathless Ingress entries: either can still render naming a Service the chart
  never creates. Reproduce with `helm template gx src/groundx --set groundx.enabled=false --set
  groundx.ingress.enabled=true --set groundx.ingress.hostName=foo.example.com -s
  templates/resources/ingress.yaml` — the rendered Ingress names backend `groundx`, and no
  `groundx` Service renders under that flag pair. *(ticket to file)*
