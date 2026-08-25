# layout-ocr-credentials-render Specification

## Purpose
TBD - created by archiving change gx-11-groundx-helm-chart-026-helm-template-fails-with-google-ocr. Update Purpose after archive.
## Requirements
### Requirement: Celery template's `$hasOCR` guard renders valid YAML on every branch

`src/groundx/templates/app/celery.yaml` (and its manual mirror `helm/templates/app/celery.yaml`) SHALL render as valid YAML whether the `$hasOCR` guard (`layout.ocr.credentials` configured, e.g. Google Cloud Vision OCR) evaluates true or false. Rendering SHALL NOT depend on any guard site right-trimming the newline and indentation that keeps the guarded mapping key (the `ocr-credentials-hash` annotation, the `credentials-volume` volume mount, and the `credentials-volume` volume) on its own line.

#### Scenario: Google OCR configured renders as valid YAML (polarity: finalize success)

- **GIVEN** `layout.ocr.type=google` and `layout.ocr.credentials` points at
  a packaged credentials file that exists in the chart at render time
- **WHEN** `helm template` renders the chart (`src/groundx` and,
  independently, the `helm/` mirror)
- **THEN** the render exits `0` and produces valid YAML, with the guarded
  `ocr-credentials-hash` annotation, `credentials-volume` volume mount, and
  `credentials-volume` volume each on their own line and indentation
- **AND THEN** the render does **NOT** fail with `error converting YAML to
  JSON: yaml: line N: mapping values are not allowed in this context` (the
  opposite outcome — a guarded key concatenated onto the previous mapping
  key — must not occur; this is the case an unfixed or only-partially-fixed
  guard site is caught by)

#### Scenario: Default/Tesseract path is unaffected (polarity: finalize success; must-not-block case)

- **GIVEN** `layout.ocr.credentials` is unset (the default/Tesseract path,
  `$hasOCR` false — every values file the chart ships or tests with today)
- **WHEN** `helm template` renders the chart (`src/groundx` and the `helm/`
  mirror), including `helm unittest`'s existing golden-snapshot suite
- **THEN** the render exits `0` exactly as it did before this change
- **AND THEN** the rendered output for `celery.yaml` is unchanged from
  before this fix — no new or removed blank lines, no annotation, volume
  mount, or volume appears on the false branch — so no existing
  `helm unittest` snapshot is altered by this fix (the opposite outcome —
  the fix perturbing the untouched branch's output — must not occur)

