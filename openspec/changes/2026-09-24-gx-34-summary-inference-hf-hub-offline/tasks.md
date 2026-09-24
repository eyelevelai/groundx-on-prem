## 1. `summary-inference` gets `HF_HUB_OFFLINE=1`, scoped to that service only

- [x] 1.1 In `src/groundx/templates/app/inference.yaml`, add a container `env` entry
      `HF_HUB_OFFLINE: "1"`, gated on `{{- if eq $mapPrefix "summary" }}`, immediately after the
      existing static `POD_NAME` entry.
      check: helm template gx-check src/groundx -f src/groundx/values.yaml -s templates/app/inference.yaml | grep -A1 "name: HF_HUB_OFFLINE" | grep -q '"1"'
- [x] 1.2 Confirm `layout-inference` and `ranker-inference` do not carry the new variable.
      check: bash -c "helm template gx-check src/groundx -f src/groundx/values.yaml -s templates/app/inference.yaml | awk '/name: layout-inference\$|name: ranker-inference\$/,/^---/' | grep -q HF_HUB_OFFLINE && exit 1 || exit 0"
- [x] 1.3 Mirror the changed file into `helm/` (byte-identical to `src/groundx/`).
      check: diff src/groundx/templates/app/inference.yaml helm/templates/app/inference.yaml
- [x] 1.4 Regenerate the `inference_test.yaml` snapshot so it reflects the new variable, and review
      the diff confirms `HF_HUB_OFFLINE` appears only in the `summary-inference` container across
      every values fixture in that suite.
      check: helm unittest -u src/groundx -f 'tests/inference_test.yaml'

## 2. Full gate

- [x] 2.1 Run the repo's CI-parity validator end to end (lint, unit tests, snapshot guard,
      both-surface render checks) and confirm it is clean.
      check: bash .build/bin/validate-helm.sh

## Verified on real infrastructure (not just templates)

Confirmed directly on the `groundx-validation` test cluster with the real pinned
`summary-inference` image before this change was written: credential deleted, `HF_HUB_OFFLINE=1`
applied by hand, full pod restart, pod reached `1/1 Running`, and a real test document summarized
successfully end to end with no HuggingFace network dependency. See GX-34 for the evidence files.

## Deferred follow-ups

- The `g34b` artifact itself still contains the leaked credential files and the leaked token has
  not been rotated. Both need HuggingFace account access this change does not have. Tracked on
  GX-34, owned by the ticket's other assignee — this change alone does not close GX-34.
- `ranker-inference`'s `USE_TF` gap (no `env` key for that service either, must be set by hand
  after every upgrade) is a materially identical, already-known issue, not fixed here. A generic
  per-service `env` override in `values.yaml` would fix both at once but is a larger, separate
  piece of work. *(ticket to file, if one does not already exist for the ranker gap)*
