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

The `$mountOCR` guard in `src/groundx/templates/app/celery.yaml` (and its byte-identical mirror `helm/templates/app/celery.yaml`) SHALL evaluate true only for the Celery worker whose Deployment `layout-ocr-credentials.yaml` actually creates an OCR-credentials Secret for (the layout `ocr` worker), never for any other Celery worker produced by the same `range`, regardless of that other worker's own settings; a worker for which no OCR-credentials Secret exists SHALL never carry the `ocr-credentials-hash` annotation, the `/app/credentials.json` volume mount, or a `credentials-volume` volume. Invariant: a worker may carry this wiring only when a Secret that satisfies the exact reference it would emit (the layout worker's own OCR Secret, or the already layout-scoped shared-Google Secret) actually exists for that worker.

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

#### Scenario: the layout OCR worker keeps its own credential wiring (polarity: finalize success; must-not-block case)

- **GIVEN** the same mixed configuration (packaged layout OCR credentials, extraction and
  workspace workers all enabled)
- **WHEN** `helm template` renders the chart (both chart surfaces)
- **THEN** the layout OCR worker's Deployment (`layout-ocr`) still renders the
  `ocr-credentials-hash` annotation, the `/app/credentials.json` volume mount, and a
  `credentials-volume` volume backed by `layout-ocr-credentials-map`
- **AND THEN** this holds with extraction and workspace workers active alongside it — a guard
  narrowed to fix the leak must not also strip the wiring from the one worker that legitimately
  needs it (an over-scoped guard is caught here, not just an under-scoped one)

#### Scenario: shared Google credentials on the layout worker are unaffected (polarity: finalize success)

- **GIVEN** `google.credentials` or `google.existingSecret` is configured (the shared-credential
  path) with `layout.ocr.credentials` unset, and extraction/workspace workers are enabled
- **WHEN** `helm template` renders the chart (both chart surfaces)
- **THEN** the layout OCR worker still mounts the shared Google credentials Secret exactly as
  before this change
- **AND THEN** no extraction or workspace worker mounts it either

