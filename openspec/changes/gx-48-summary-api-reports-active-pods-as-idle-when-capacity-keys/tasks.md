## 1. Thin slice: the per-process inference value renders in `src/groundx`

- [ ] 1.1 In `src/groundx/templates/resources/config-yaml.yaml`, define `$saw` and `$sacw` next to `$sac`
      and render `$sacw` in the `summary-api` entry of `metrics.inference` only (the `metrics.throughput`
      entry keeps `$sat`). Covers the new `resources_test.yaml` case "summary-api inference capacity is
      per gunicorn process while throughput stays per pod".
      check: bash -c 'H="${GX_ON_PREM_HELM:-helm}"; r=$("$H" template gx src/groundx -f src/groundx/values/minikube/values.yaml --set summary.api.workers=2 --show-only templates/resources/config-yaml.yaml) && echo "$r" | awk "/^      inference:/{f=1} /^      page:/{f=0} f" | grep -A1 "name: summary-api" | grep -q "tokensPerMinute: 9600" && echo "$r" | awk "/^      throughput:/{f=1} f" | grep -A1 "name: summary-api" | grep -q "tokensPerMinute: 19200"'

## 2. Mirror into `helm/`

- [ ] 2.1 Copy the changed file to `helm/templates/resources/config-yaml.yaml` so the two stay
      byte-identical, and confirm the mirror renders the per-process value.
      check: bash -c 'H="${GX_ON_PREM_HELM:-helm}"; diff src/groundx/templates/resources/config-yaml.yaml helm/templates/resources/config-yaml.yaml && "$H" template gx helm -f helm/values/minikube/values.yaml --set summary.api.workers=2 --show-only templates/resources/config-yaml.yaml | awk "/^      inference:/{f=1} /^      page:/{f=0} f" | grep -A1 "name: summary-api" | grep -q "tokensPerMinute: 9600"'

## 3. Snapshots and full gate

- [ ] 3.1 Regenerate exactly the three snapshot cases whose fixture sets summary `workers: 2`
      (`metadata: resources` in `resources_test.yaml`, `metadata: golang` in `golang_test.yaml` and
      `metrics_test.yaml`) using the gate's OCR-fixture setup, not a bare `helm unittest`. Review the
      diff: only the `myapp-api` inference value and config-hash lines may change; any other snapshot
      changing is a defect. Then run the repo's CI-parity validator end to end (lint of both chart
      surfaces, unit tests, snapshot guard, mirror render checks, whitespace) on helm v3.19.0.
      check: bash -c 'd=$(mktemp -d) && ln -s "${GX_ON_PREM_HELM:-$(command -v helm)}" "$d/helm" && PATH="$d:$PATH" bash .build/bin/validate-helm.sh'

## Rollout and coupling (prose, not tasks)

Release together with ai-server#66 (`<HOSTNAME>-<pid>` capacity ids); see `proposal.md` Impact for the
order-dependent effect when `summary.api.workers > 1`. See workspace
`openspec/changes/gx-48-summary-api-reports-active-pods-as-idle-when-capacity-keys/tasks.md` for
cross-service coordination and deferred items.
