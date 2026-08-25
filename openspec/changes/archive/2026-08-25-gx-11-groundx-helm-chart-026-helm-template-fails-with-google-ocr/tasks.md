## 1. Fix the `$hasOCR` guard render bug (end-to-end slice)

- [x] 1.1 In `src/groundx/templates/app/celery.yaml`, change the three
  `{{- if eq $hasOCR "true" -}}` guards (verified at lines 66, 174, 189) to
  `{{- if eq $hasOCR "true" }}` — drop the trailing `-` on the opening tag
  only; leave the paired `{{- end }}` tags unchanged.
  check: bash -c 'trap "rm -f src/groundx/files/ocr/credentials.json" EXIT; mkdir -p src/groundx/files/ocr && printf "{}" > src/groundx/files/ocr/credentials.json && helm template gx src/groundx -n eyelevel --set layout.ocr.type=google --set layout.ocr.project=p --set layout.ocr.credentials=files/ocr/credentials.json > /dev/null && helm template gx src/groundx -n eyelevel > /dev/null'
- [x] 1.2 Apply the identical edit to the manual mirror
  `helm/templates/app/celery.yaml` (same three sites) — `helm/` is not an
  independently maintained source, so this fix must ship in both files.
  check: bash -c 'trap "rm -f helm/files/ocr/credentials.json" EXIT; mkdir -p helm/files/ocr && printf "{}" > helm/files/ocr/credentials.json && helm template gx helm -n eyelevel --set layout.ocr.type=google --set layout.ocr.project=p --set layout.ocr.credentials=files/ocr/credentials.json > /dev/null && helm template gx helm -n eyelevel > /dev/null'

## 2. Regression + housekeeping verification

- [x] 2.1 Run the full `helm unittest src/groundx` golden-snapshot suite and
  compare it against the pre-fix baseline (202 tests / 815 snapshots,
  recorded in design.md). No committed test values file sets
  `layout.ocr.type: google` / `layout.ocr.credentials`, so no snapshot is
  expected to change. If the suite nonetheless reports a diff, regenerate
  with `helm unittest -u src/groundx` and commit the regenerated
  `src/groundx/tests/__snapshot__/celery_test.yaml.snap` before marking
  this task done — do not hand-edit the snapshot file.
  check: n/a — verification/housekeeping, not new behavior: confirmed via
  design.md's Decisions section that this fix cannot change any existing
  snapshot (no fixture exercises `$hasOCR` true), and confirmed empirically
  that `helm unittest src/groundx` already passes 202/202 on the unchanged
  code, so a runnable check here would be vacuous under the RED baseline —
  it can only ever pass, both before and after this change, unless the
  above grounding is wrong. Run it anyway during apply/verify and report
  its result verbatim.
- [x] 2.2 Record in the PR/commit body that no `values.yaml`,
  `values.schema.json`, `_helpers/*.tpl`, or `Chart.yaml` file changed, and
  that no rollout/canary/secret/migration step is required beyond a normal
  chart release (per design.md's Migration Plan).
  check: n/a — documentation/record-keeping task, no behavior to assert.
