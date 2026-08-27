## Why

Enabling Google Cloud Vision OCR (`layout.ocr.type: google`) makes `helm template`
(and therefore `helm install`/`helm upgrade`) fail with `error converting YAML to
JSON: yaml: line 23: mapping values are not allowed in this context`. The values
supplied are valid; the fault is a whitespace-chomp bug in
`templates/app/celery.yaml`: the three `{{- if eq $hasOCR "true" -}}` guards use a
trailing `-}}`, which right-trims the newline and indentation after the `if`, so
the guarded line (e.g. `ocr-credentials-hash: <sha>`) is concatenated onto the
previous mapping key on one line — two keys on one line is invalid YAML. This
blocks the Google-OCR path (the harness-recommended AWS-cloud OCR configuration,
tracked against GX-4 B2) for every environment, including the currently checked
out `0.2.7` chart, and would also block any future customer install using
Google OCR from the published chart once `0.2.7` ships.

## What Changes

- In `src/groundx/templates/app/celery.yaml`, change the three OCR guards from
  `{{- if eq $hasOCR "true" -}}` to `{{- if eq $hasOCR "true" }}` (drop the
  trailing `-` on the opening guard only), so the guarded mapping key keeps its
  own line and indentation instead of being chomped onto the previous line.
- Apply the identical edit to the manual mirror `helm/templates/app/celery.yaml`
  (per this repo's `helm/` ↔ `src/groundx/` sync convention — `helm/` is not an
  independently maintained source).
- No other guard, template, `_helpers`, `values.yaml`/`values.schema.json`, or
  `Chart.yaml` change.

## Capabilities

### New Capabilities

- `layout-ocr-credentials-render`: the `celery.yaml` OCR-credentials guard
  (`$hasOCR`) must render as valid YAML — the guarded mapping key(s) stay on
  their own line, both when the guard is true (Google OCR configured) and when
  it is false (default/Tesseract) — so `helm template`/`helm install` never fails
  on this construct.

### Modified Capabilities

None. No existing `openspec/specs/` capability documents this rendering path
today.

## Impact

- **Blast radius:** template-only change to one file (plus its manual mirror).
  No `values.yaml`, `values.schema.json`, `_helpers`, or `Chart.yaml` change, so
  no version bump and no change to the values contract. Every environment that
  renders `celery.yaml` re-renders on the next `helm template`/`upgrade`, but the
  rendered output is byte-identical to today's except for the three guard sites
  — unchanged when Google OCR is not configured (`$hasOCR` false, the current
  default/Tesseract path), and now valid YAML instead of a parse error when it
  is configured (Google OCR).
- **Affected environments:** every environment on this chart (eks/aks/gke/
  openshift/minikube) that would enable `layout.ocr.type=google`. No environment
  is currently running with Google OCR enabled today, because the current chart
  cannot render with it — so this fix is strictly unblocking, not a behavior
  change to any running deployment.
- **Stateful impact:** none. No database, queue, cache, or storage change; no
  data migration.
- **Rollout risk:** minimal — a two-character whitespace fix confined to a
  `helm template` YAML-structure bug. Verify with `helm lint` and `helm template`
  (both Tesseract-default and `layout.ocr.type=google` value sets) before merge,
  and confirm the existing `helm unittest` snapshot suite still matches (the
  chart's only CI gate on template changes) — regenerate the affected snapshot(s)
  if the rendered whitespace changes the golden output.
- **Rollforward:** land on this `0.2.7` branch; no separate deployment step is
  required beyond the normal chart release/publish process, since this is a
  render-time template bug, not a runtime behavior change.
- **Rollback:** revert the two-file edit. No data or running-deployment rollback
  is needed — nothing currently depends on the broken behavior, since no
  environment can render with Google OCR enabled today.
- **Open design questions:** none.
