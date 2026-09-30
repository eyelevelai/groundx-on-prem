## 1. Thin slice: metrics budget and spread, end to end

- [x] 1.1 Add `_helpers/elements/topologyspread.tpl` (`groundx.renderTopologySpread`), call it beside `renderTolerations` in `app/metrics.yaml`, add the PodDisruptionBudget block keyed on `$svc`, pass both keys in `_helpers/app/metrics.tpl`, add the schema objects and the `metrics.disruptionBudget.enabled: false` default in `src/groundx`.
  check: bash -c '"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" template gx-check src/groundx -f src/groundx/tests/files/values.disabled.yaml --set metrics.enabled=true --set metrics.disruptionBudget.enabled=true -s templates/app/metrics.yaml | grep -q "kind: PodDisruptionBudget"'
- [x] 1.2 Mirror the slice into `helm/` (templates and schema identical; `values.yaml` default added by hand, its unrelated drift left alone).
  check: "${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" unittest helm -f 'tests/drain_protection_test.yaml'

## 2. Go workers and groundx

- [x] 2.1 Call the spread helper in `app/golang.yaml` and pass `disruptionBudget` and `topologySpreadConstraints` in the summary-client, pre-process, process, queue, upload, layout-webhook and large-file-deliver helpers (spread only in `groundx.tpl`); add schema entries and `values.yaml` defaults.
  check: bash -c '"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" template gx-check src/groundx -f src/groundx/tests/files/values.disabled.yaml --set summaryClient.enabled=true --set summaryClient.disruptionBudget.enabled=true -s templates/app/golang.yaml | grep -A16 "kind: PodDisruptionBudget" | grep -q "app: \"summary-client\""'
- [x] 2.2 Mirror task 2.1 into `helm/`.
  check: bash -c 'diff -rq src/groundx/templates helm/templates && diff -q src/groundx/values.schema.json helm/values.schema.json && grep -q topologySpreadConstraints helm/templates/app/golang.yaml'

## 3. Celery workers

- [x] 3.1 Add the PodDisruptionBudget block keyed on `$name` and the spread call to `app/celery.yaml`; pass both keys in the 13 layout, extract and workspace worker helpers; add schema entries and defaults.
  check: bash -c 'test "$("${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" template gx-check src/groundx -f src/groundx/tests/files/values.disabled.yaml --set layout.map.enabled=true --set layout.map.disruptionBudget.enabled=true --set layout.ocr.enabled=true --set layout.ocr.disruptionBudget.enabled=true -s templates/app/celery.yaml | grep -c "kind: PodDisruptionBudget")" = 2'
- [x] 3.2 Mirror task 3.1 into `helm/`.
  check: bash -c 'diff -rq src/groundx/templates helm/templates && diff -q src/groundx/values.schema.json helm/values.schema.json && grep -q topologySpreadConstraints helm/templates/app/celery.yaml'

## 4. Inference services

- [x] 4.1 Add the PodDisruptionBudget block and spread call to `app/inference.yaml`; pass both keys in the layout, ranker and summary inference helpers; add schema entries and defaults.
  check: bash -c '"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" template gx-check src/groundx -f src/groundx/tests/files/values.disabled.yaml --set layout.inference.enabled=true --set layout.inference.disruptionBudget.enabled=true -s templates/app/inference.yaml | grep -q "kind: PodDisruptionBudget"'
- [x] 4.2 Mirror task 4.1 into `helm/`.
  check: bash -c 'diff -rq src/groundx/templates helm/templates && diff -q src/groundx/values.schema.json helm/values.schema.json && grep -q topologySpreadConstraints helm/templates/app/inference.yaml'

## 5. Spread on the API services

- [x] 5.1 Call the spread helper in `app/api.yaml` and pass `topologySpreadConstraints` in the five API helpers; add schema entries.
  check: bash -c '"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" template gx-check src/groundx -f src/groundx/tests/files/values.disabled.yaml --set layout.api.enabled=true --set-json layout.api.topologySpreadConstraints=[{\"maxSkew\":1}] -s templates/app/api.yaml | grep -q "topologySpreadConstraints"'
- [x] 5.2 Mirror task 5.1 into `helm/`.
  check: bash -c 'diff -rq src/groundx/templates helm/templates && diff -q src/groundx/values.schema.json helm/values.schema.json && grep -q topologySpreadConstraints helm/templates/app/api.yaml'

## 6. Whole-change verification

- [x] 6.1 The extended suite passes on both chart surfaces and leaves existing snapshots untouched.
  check: bash -c '"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" unittest src/groundx -f tests/api_pdb_test.yaml && "${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" unittest helm -f tests/drain_protection_test.yaml && git diff --exit-code -- src/groundx/tests/__snapshot__'
- [x] 6.2 Lint and full unit suites pass through the repo's canonical gate.
  check: bash .build/bin/validate-helm.sh

See workspace `openspec/changes/gx-74-the-helm-chart-cannot-protect-groundx-services-from-a-node/tasks.md` for cross-service coordination and deferred items (harness documentation follow-up).

## Amendments

### 2026-09-29: task 2.1 check corrected

The original check for task 2.1 grepped for `name: summary-client`, which the summary-client Deployment also carries, so it passed without a PodDisruptionBudget. The corrected check requires the rendered PodDisruptionBudget document itself to carry the `app: "summary-client"` label. Run against the chart, it exited 0 with `summaryClient.disruptionBudget.enabled=true` and exited 1 with it set to `false`.

Corrected check: bash -c '"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" template gx-check src/groundx -f src/groundx/tests/files/values.disabled.yaml --set summaryClient.enabled=true --set summaryClient.disruptionBudget.enabled=true -s templates/app/golang.yaml | grep -A16 "kind: PodDisruptionBudget" | grep -q "app: \"summary-client\""'

### 2026-09-30: review follow-ups (replica-minimum warning, all-30 render guard, usable spread fixture)

Approved review of PR #125 raised three non-blocking points, taken here. The fourth, `unhealthyPodEvictionPolicy`, is a separate ticket.

- [x] 7.1 `templates/NOTES.txt` warns per service when a disruption budget is on and the effective minimum replica count is below 2, resolved from the services' own settings helpers and the chart's HPA selection; a warning, not a `fail`, so installs that already work keep working. Output with no budget enabled is unchanged.
  check: bash -c '"${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" unittest src/groundx -f tests/api_pdb_test.yaml'
- [x] 7.2 Mirror task 7.1 into `helm/` and cover it with one case in `helm/tests/drain_protection_test.yaml`.
  check: bash -c 'diff -rq src/groundx/templates helm/templates && "${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" unittest helm -f tests/drain_protection_test.yaml'
- [x] 8.1 `.build/bin/validate-helm.sh` renders both charts with the budget and a spread on all 30 services, set by `--set` flags built from a service array over `values.large-file.yaml`, and requires exactly 30 PodDisruptionBudgets and 30 pod specs carrying `topologySpreadConstraints`.
  check: bash -c 'grep -q "all 30 workloads" .build/bin/validate-helm.sh && ! test -e src/groundx/tests/files/values.drain-all.yaml && grep -c "disruptionBudget.enabled=true" .build/bin/validate-helm.sh'
- [x] 9.1 The spread fixtures in `src/groundx/tests/api_pdb_test.yaml` carry a `labelSelector` matching each service's own `app` label.
  check: bash -c 'test "$(grep -c "^ *app: " src/groundx/tests/api_pdb_test.yaml)" -ge 6 && "${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}" unittest src/groundx -f tests/api_pdb_test.yaml'
