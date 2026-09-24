# layout-ocr-credentials-render Specification

## Purpose
Guarantee that `celery.yaml`'s `$hasOCR` conditional blocks (the OCR credentials annotation, volume mount, and volume) render as valid YAML on both the Google-OCR and default/Tesseract branches, in `src/groundx` and its `helm/` mirror alike.
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

### Requirement: Layout Celery OCR credential wiring is scoped to layout workers only

When OCR is enabled with packaged `layout.ocr.credentials`, the `$mountOCR` guard in `src/groundx/templates/app/celery.yaml` and its mirror `helm/templates/app/celery.yaml` SHALL preserve the `ocr-credentials-hash` annotation, `/app/credentials.json` mount and credentials Secret volume on every enabled layout Celery worker: correct, map, ocr, process and save. These workers share the layout credential Secret and initialize OCR through the same Celery application. Non-layout Celery workers SHALL receive none of this layout OCR wiring. Existing shared-Google source selection and explicitly configured existing Secrets SHALL remain supported.

#### Scenario: packaged layout OCR credentials do not leak onto extraction workers (polarity: reject before state)

- **GIVEN** `layout.ocr.type=google` and `layout.ocr.credentials` points at a packaged
  credentials file, and extraction background workers (`extract.enabled`,
  `extract.download.enabled`, `extract.save.enabled`) are also enabled
- **WHEN** `helm template` renders the chart (`src/groundx` and, independently, the `helm/`
  mirror)
- **THEN** the extraction worker's Deployment (`extract-download`) renders with no
  `ocr-credentials-hash` annotation, no `/app/credentials.json` volume mount, and no
  `credentials-volume` volume referencing `extract-ocr-credentials-map`
- **AND THEN** the render is asserted to actually contain the `extract-download` Deployment
  resource, so the assertion cannot pass merely because that worker was disabled (the opposite
  outcome — a worker rendering absent and the absence of wiring being coincidental rather than
  guarded — must not occur)

#### Scenario: packaged layout OCR credentials do not leak onto workspace workers (polarity: reject before state)

- **GIVEN** the same packaged `layout.ocr.credentials` configuration as above, and a workspace
  background worker (`workspace.enabled` with a token) is also enabled
- **WHEN** `helm template` renders the chart (both chart surfaces)
- **THEN** the workspace worker's Deployment (`workspace-workspace`) renders with no
  `ocr-credentials-hash` annotation, no `/app/credentials.json` volume mount, and no
  `credentials-volume` volume referencing `workspace-ocr-credentials-map`
- **AND THEN** the render is asserted to actually contain the `workspace-workspace` Deployment
  resource, for the same not-vacuously-absent reason as above

#### Scenario: all layout Celery workers keep their credential wiring (polarity: finalize success; must-not-block case)

- **GIVEN** packaged layout OCR credentials, all five layout Celery workers, extraction and
  workspace workers are enabled
- **WHEN** `helm template` renders the chart (both chart surfaces)
- **THEN** each Deployment (`layout-correct`, `layout-map`, `layout-ocr`, `layout-process`
  and `layout-save`, using default service names) renders the
  `ocr-credentials-hash` annotation, the `/app/credentials.json` volume mount, and a
  `credentials-volume` volume backed by `layout-ocr-credentials-map`
- **AND** each Deployment is asserted present and checked individually, so missing workers
  or credentials on only `layout-ocr` cannot satisfy the requirement

#### Scenario: shared Google credentials on layout workers are unaffected (polarity: finalize success)

- **GIVEN** `google.credentials` or `google.existingSecret` is configured (the shared-credential
  path) with `layout.ocr.credentials` unset, and extraction/workspace workers are enabled
- **WHEN** `helm template` renders the chart (both chart surfaces)
- **THEN** enabled layout Celery workers still mount the shared Google credentials Secret exactly as
  before this change
- **AND THEN** no extraction or workspace worker mounts it either
