## 1. Default for the two optional workers (thin slice)

- [x] 1.1 Add the default, override and schema cases to `src/groundx/tests/golang_test.yaml`, `resources_test.yaml` and `post-process_test.yaml`, then default `gracePeriod` to 900 and render `drainSeconds` in `src/groundx/templates/_helpers/app/large-file-deliver.tpl` and `post-process.tpl`
  check: helm unittest -f 'tests/golang_test.yaml' -f 'tests/resources_test.yaml' -f 'tests/post-process_test.yaml' src/groundx
- [x] 1.2 Mirror the identical template changes into `helm/templates/_helpers/app/`
  check: cmp src/groundx/templates/_helpers/app/post-process.tpl helm/templates/_helpers/app/post-process.tpl && cmp src/groundx/templates/_helpers/app/large-file-deliver.tpl helm/templates/_helpers/app/large-file-deliver.tpl
- [x] 1.3 Add `gracePeriod` to both workers' `replicas` blocks in `src/groundx/values.schema.json` and `helm/values.schema.json`
  check: cmp src/groundx/values.schema.json helm/values.schema.json

## 2. Snapshots, docs and spec

- [x] 2.1 Hand-patch the six snapshot entries that render an enabled worker (config-hash lines, one `terminationGracePeriodSeconds: 900`, one `drainSeconds: 870` each), without `helm unittest -u`
  check: n/a — verified by the full gate, which runs `helm unittest` against the committed snapshots and the snapshot-stability guard
- [x] 2.2 Document `replicas.gracePeriod` in `docs/agents/large-file-delivery.md` and `docs/agents/post-processing.md`, and update `openspec/specs/queue-service-grace-period/spec.md`
  check: grep -q 'replicas.gracePeriod' docs/agents/large-file-delivery.md && grep -q 'postProcess.replicas.gracePeriod' docs/agents/post-processing.md
- [x] 2.3 Run the full gate
  check: n/a — runs the repo CI gate `.build/bin/validate-helm.sh` (also generates the OCR credentials fixture), which needs a full toolchain and a clean tree; it is the verify step, not a behavioral task
