## 1. Thin slice: API budget end to end

- [x] 1.1 Add `unhealthyPodEvictionPolicy: AlwaysAllow` directly after `minAvailable: 1` in the PodDisruptionBudget block of `src/groundx/templates/app/api.yaml`, then apply the identical edit to `helm/templates/app/api.yaml`
  check: helm template src/groundx --kube-version 1.27.0 --set extract.enabled=true,extract.api.enabled=true,extract.api.disruptionBudget.enabled=true --show-only templates/app/api.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow' && helm template helm --kube-version 1.27.0 --set extract.enabled=true,extract.api.enabled=true,extract.api.disruptionBudget.enabled=true --show-only templates/app/api.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow'

## 2. Remaining budget templates

- [x] 2.1 Add the same field after `minAvailable: 1` in `templates/app/golang.yaml`, in `src/groundx` then `helm/`
  check: helm template src/groundx --kube-version 1.27.0 --set groundx.enabled=true,groundx.disruptionBudget.enabled=true --show-only templates/app/golang.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow' && helm template helm --kube-version 1.27.0 --set groundx.enabled=true,groundx.disruptionBudget.enabled=true --show-only templates/app/golang.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow'
- [x] 2.2 Add the same field after `minAvailable: 1` in `templates/app/celery.yaml`, in `src/groundx` then `helm/`; the enabled `layout.map` and `layout.ocr` case renders two budgets and both carry the field
  check: [ "$(helm template src/groundx --kube-version 1.27.0 --set layout.map.enabled=true,layout.map.disruptionBudget.enabled=true,layout.ocr.enabled=true,layout.ocr.disruptionBudget.enabled=true --show-only templates/app/celery.yaml | grep -c 'unhealthyPodEvictionPolicy: AlwaysAllow')" = 2 ] && [ "$(helm template helm --kube-version 1.27.0 --set layout.map.enabled=true,layout.map.disruptionBudget.enabled=true,layout.ocr.enabled=true,layout.ocr.disruptionBudget.enabled=true --show-only templates/app/celery.yaml | grep -c 'unhealthyPodEvictionPolicy: AlwaysAllow')" = 2 ]
- [x] 2.3 Add the same field after `minAvailable: 1` in `templates/app/inference.yaml`, in `src/groundx` then `helm/`
  check: helm template src/groundx --kube-version 1.27.0 --set layout.inference.enabled=true,layout.inference.disruptionBudget.enabled=true --show-only templates/app/inference.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow' && helm template helm --kube-version 1.27.0 --set layout.inference.enabled=true,layout.inference.disruptionBudget.enabled=true --show-only templates/app/inference.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow'
- [x] 2.4 Add the same field after `minAvailable: 1` in `templates/app/metrics.yaml`, in `src/groundx` then `helm/`
  check: helm template src/groundx --kube-version 1.27.0 --set metrics.enabled=true,metrics.disruptionBudget.enabled=true --show-only templates/app/metrics.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow' && helm template helm --kube-version 1.27.0 --set metrics.enabled=true,metrics.disruptionBudget.enabled=true --show-only templates/app/metrics.yaml | grep -q 'unhealthyPodEvictionPolicy: AlwaysAllow'

## 3. Unit suites assert the field

- [x] 3.1 Confirm the assertions added to `src/groundx/tests/api_pdb_test.yaml` (api, golang, inference, metrics once each; celery at `documentIndex` 1 and 3) pass against the edited templates, without `-u`
  check: helm unittest src/groundx -f tests/api_pdb_test.yaml
- [x] 3.2 Confirm the assertion added to `helm/tests/drain_protection_test.yaml` (metrics budget on the published chart) passes, without `-u`
  check: helm unittest helm -f tests/drain_protection_test.yaml

## 4. Gate

- [x] 4.1 Run `helm lint src/groundx`, `helm lint helm` and the full `helm unittest src/groundx helm src/groundx/prereqs/kafka-cluster`, confirm no snapshot file is modified, and confirm `diff -r src/groundx/templates helm/templates` is empty (the mirror comparison `validate-helm.sh` runs)
  check: n/a — whole-chart regression gate that already passes on the unchanged chart; the new behavior is checked by tasks 1.1 to 3.2

See workspace `openspec/changes/gx-84-a-groundx-service-whose-pods-are-all-unready-blocks-a-node/tasks.md` for cross-service coordination and deferred items.

## 6. Kubernetes compatibility

- [x] 6.1 Add failing version regression cases to the existing source and mirror budget suites. Cover field absence before 1.26 and presence from 1.26, with minAvailable and selectors preserved.
- [x] 6.2 Guard the field with `semverCompare ">=1.26-0" $.Capabilities.KubeVersion.Version` in the five source templates, then copy the same files to the mirror.
- [x] 6.3 Make the API availability spec version conditional. Run the full chart gate and minikube render. Validate normal Helm install checking against an isolated Kubernetes 1.21 cluster.
- [x] 6.4 Settle and remove the exact registered local run root, retain its bounded summary and closeout receipt, then archive the change.
- [x] 6.5 Commit and push the existing PR branch after confirming its remote head is unchanged. Preserve the Harness documentation release gate.

Validation: 413 Helm tests and 850 snapshots pass. Both chart copies pass normal Helm install validation on an isolated Kubernetes 1.21.14 cluster. All 30 budgets preserve minAvailable and selectors across the version checks; default renders are unchanged. Minikube rendering passes.
