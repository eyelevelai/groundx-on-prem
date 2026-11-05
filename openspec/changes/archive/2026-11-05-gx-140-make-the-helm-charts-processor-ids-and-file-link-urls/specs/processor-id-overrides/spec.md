## ADDED Requirements

### Requirement: Layout, map and summarize take exactly one processor ID
The values schema SHALL give `cluster.processors.layout`, `cluster.processors.map` and `cluster.processors.summarize` `"minItems": 1` and `"maxItems": 1`, so a values file that sets any of them to two or more IDs fails schema validation and Helm renders no manifest. The GroundX API and pre-process servers stop at startup unless each of these three lists holds exactly one ID (cashbot-go `pkg/copy/copy.go:61-72` at `1bc6431ccc`, called from `copy.NewCopier`, whose error `server/GroundX/main.go:251-258` and `server/PreProcessTrainFile/main.go:209-212` treat as fatal). No other list under `cluster.processors` SHALL carry `maxItems`. The two `values.schema.json` files SHALL stay byte-identical.

#### Scenario: Two layout IDs are rejected (reject before state)
- **GIVEN** a values file that sets `cluster.processors.layout: [3, 118]`
- **WHEN** Helm validates the values
- **THEN** schema validation fails with an error naming `/cluster/processors/layout` and `maxItems`
- **AND** no manifest renders, so no `config-yaml-map` Secret carrying two layout IDs is produced

#### Scenario: Two map IDs are rejected (reject before state)
- **GIVEN** a values file that sets `cluster.processors.map: [4, 120]`
- **WHEN** Helm validates the values
- **THEN** schema validation fails with an error naming `/cluster/processors/map` and `maxItems`
- **AND** no manifest renders

#### Scenario: Two summarize IDs are rejected (reject before state)
- **GIVEN** a values file that sets `cluster.processors.summarize: [8, 125]`
- **WHEN** Helm validates the values
- **THEN** schema validation fails with an error naming `/cluster/processors/summarize` and `maxItems`
- **AND** no manifest renders

#### Scenario: One ID for each single-ID list still renders (must not block)
- **GIVEN** a values file that sets `cluster.processors.layout: [118]`, `cluster.processors.map: [120]` and `cluster.processors.summarize: [125]` alongside the other ten lists (the "processor overrides render every configured list" case)
- **WHEN** the chart renders `config.yaml`
- **THEN** rendering succeeds and `processors` lists `layout: [118]`, `map: [120]` and `summarize: [125]`
- **AND** schema validation does not fail

#### Scenario: Two skipGenerate IDs still render (must not block)
- **GIVEN** the ingest-mode values file `tests/files/values.extract.ingest.yaml` and `cluster.processors.skipGenerate: [4, 5]`
- **WHEN** the chart renders `config.yaml`
- **THEN** rendering succeeds and `processors.skipGenerate` is `[4, 5]`
- **AND** schema validation does not fail, because the single-ID limit applies only to `layout`, `map` and `summarize`

#### Scenario: Validated by the chart suite
- **WHEN** `tests/resources_test.yaml` runs on a copy of `src/groundx`
- **THEN** the cases "two layout processor IDs fail schema validation", "two map processor IDs fail schema validation" and "two summarize processor IDs fail schema validation" pass with a `failedTemplate` assertion on the schema error
- **AND** the cases "processor overrides render every configured list" and "ingest mode builds extraPostDefaults from the configured skipGenerate IDs" still pass

### Requirement: The values comment names the single-ID lists and the unread lists
The comment above `cluster.processors` in `src/groundx/values.yaml` and `helm/values.yaml` SHALL state that `layout`, `map` and `summarize` take exactly one ID, and SHALL name the six lists the GroundX server does not read: `saveFile`, `skipConvert`, `skipLayout`, `skipMap`, `summarizeChunks` and `summarizeSections`. At cashbot-go `1bc6431ccc` those six exist only as config struct fields (`pkg/config/api.go:91-107`), with no non-test `Processors.<field>` reference. The comment SHALL stay a short knob description with no commented-out example and no ticket or person reference, and the two `values.yaml` files SHALL stay byte-identical.

#### Scenario: Comment carries both facts (finalize success)
- **WHEN** an operator reads the comment lines directly above `processors:` under `cluster` in either `values.yaml`
- **THEN** the comment says `layout`, `map` and `summarize` take exactly one ID
- **AND** it names `saveFile`, `skipConvert`, `skipLayout`, `skipMap`, `summarizeChunks` and `summarizeSections` as lists the server does not read

#### Scenario: Default value unchanged (must not block)
- **WHEN** either `values.yaml` is parsed
- **THEN** `cluster.processors` is still `{}`, so a new install renders the default IDs

## MODIFIED Requirements

### Requirement: Each processor ID list is configurable
The chart SHALL accept an optional `cluster.processors` map whose keys are the 13 processor lists of cashbot-go's `processors` configuration (`convert`, `extract`, `layout`, `map`, `saveFile`, `skipConvert`, `skipGenerate`, `skipLayout`, `skipMap`, `skipSummarize`, `summarize`, `summarizeChunks`, `summarizeSections`). `layout`, `map` and `summarize` SHALL each take a list of exactly one integer ID; each of the other ten keys SHALL take a non-empty list of integer IDs. Each list set in the map SHALL replace that list's default in the rendered `config.yaml` `processors:` block, and each list left unset SHALL keep its default (`convert: [11]`, `extract: [13]`, `layout: [3]`, `map: [4]`, `saveFile: [2]`, `skipConvert: [12]`, `skipGenerate: [1]`, `skipLayout: [5]`, `skipMap: [6]`, `skipSummarize: [7]`, `summarize: [8]`, `summarizeChunks: [10]`, `summarizeSections: [9]`). The values schema SHALL reject any other key under `cluster.processors`, so a misspelled list name fails the render instead of being ignored. The `src/groundx` chart and the `helm/` mirror SHALL carry byte-identical templates, `values.yaml` and `values.schema.json`.

#### Scenario: Every list overridden (finalize success)
- **GIVEN** a values file that sets all 13 lists to non-default IDs (`convert: [132]`, `extract: [134]`, `layout: [118]`, `map: [120]`, `saveFile: [5]`, `skipConvert: [133]`, `skipGenerate: [4]`, `skipLayout: [119]`, `skipMap: [121]`, `skipSummarize: [123]`, `summarize: [125]`, `summarizeChunks: [124]`, `summarizeSections: [122]`) with the default `mode: all`
- **WHEN** the chart renders `config.yaml`
- **THEN** the `processors:` block lists exactly those 13 values in alphabetical key order, in the existing `key: [id]` format
- **AND** no default ID remains for any of the 13 lists, and no `extraPostDefaults` entry renders

#### Scenario: Partial override keeps the other defaults (finalize success)
- **GIVEN** a values file that sets only `cluster.processors.layout: [118]` and `cluster.processors.extract: [134]`
- **WHEN** the chart renders `config.yaml`
- **THEN** `layout` is `[118]` and `extract` is `[134]`
- **AND** the other 11 lists render their default IDs unchanged

#### Scenario: Misspelled list name is rejected (reject before state)
- **GIVEN** a values file that sets `cluster.processors.skipGeneration: [4]`
- **WHEN** Helm validates the values
- **THEN** schema validation fails and names `skipGeneration` under `cluster/processors`
- **AND** no manifest is rendered

#### Scenario: Validated by the chart gate
- **WHEN** `.build/bin/validate-helm.sh` runs with Helm v3.19.0
- **THEN** the `tests/resources_test.yaml` cases for these scenarios pass
- **AND** the template, `values.yaml` and `values.schema.json` mirror comparisons pass

### Requirement: Omitting cluster.processors renders today's processor configuration
When `cluster.processors` is absent or empty, the rendered `processors:` block, the `extraPreDefaults` entries, the ingest-mode `extraPostDefaults` entry and the `upload` section SHALL be byte-identical to chart 0.2.9 on `main` at `595510d8c`, and no `uploadGroundx` section SHALL render. The `processors` mapping SHALL also equal the 0.2.7 render at `07d332fc6c`.

#### Scenario: Existing snapshots stay unchanged (finalize success)
- **WHEN** the full helm-unittest suite runs through `.build/bin/validate-helm.sh` without `cluster.processors` in any existing fixture
- **THEN** every committed snapshot under `src/groundx/tests/__snapshot__/` matches with no update, including the `config.yaml` renders of the default, ingest (`extract.ingest`) and `cluster.preProcessors` fixtures
- **AND** no snapshot file differs from `main` at `595510d8c`, the merge base of the feature branch and `origin/main`

#### Scenario: Matches the main render of the same fixtures (finalize success)
- **GIVEN** the fixtures under `src/groundx/tests/files/` at `595510d8c` that render successfully at that commit
- **WHEN** each fixture is rendered at `595510d8c` and at the feature branch tip without `cluster.processors`
- **THEN** the `processors` mapping, including `extraPreDefaults` and `extraPostDefaults`, and the `upload` mapping are equal in both renders
- **AND** neither render has an `uploadGroundx` key
- **AND** this differential is run at verify time with named-field `yq` comparisons and its output saved outside the repository, not committed as a script

#### Scenario: Matches the 0.2.7 render of the same fixtures (finalize success)
- **GIVEN** the fixtures under `src/groundx/tests/files/` at commit `07d332fc6c` that render successfully at that commit
- **WHEN** each fixture is rendered at `07d332fc6c` and at the feature branch tip without `cluster.processors`
- **THEN** the `processors` mapping, including `extraPreDefaults` and `extraPostDefaults`, is equal in both renders
- **AND** this differential is run at verify time with named-field `yq` comparisons and its output saved outside the repository, not committed as a script
