## ADDED Requirements

### Requirement: Each processor ID list is configurable
The chart SHALL accept an optional `cluster.processors` map whose keys are the 13 processor lists cashbot-go reads (`convert`, `extract`, `layout`, `map`, `saveFile`, `skipConvert`, `skipGenerate`, `skipLayout`, `skipMap`, `skipSummarize`, `summarize`, `summarizeChunks`, `summarizeSections`). Each key SHALL take a non-empty list of integer IDs. Each list set in the map SHALL replace that list's default in the rendered `config.yaml` `processors:` block, and each list left unset SHALL keep its default (`convert: [11]`, `extract: [13]`, `layout: [3]`, `map: [4]`, `saveFile: [2]`, `skipConvert: [12]`, `skipGenerate: [1]`, `skipLayout: [5]`, `skipMap: [6]`, `skipSummarize: [7]`, `summarize: [8]`, `summarizeChunks: [10]`, `summarizeSections: [9]`). The values schema SHALL reject any other key under `cluster.processors`, so a misspelled list name fails the render instead of being ignored. The `src/groundx` chart and the `helm/` mirror SHALL carry byte-identical templates, `values.yaml` and `values.schema.json`.

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

### Requirement: Ingest-mode skip-generate entries follow the configured skipGenerate IDs
In `mode: ingest`, the chart SHALL render one `processors.extraPostDefaults` entry of `type: skip-generate` for each ID in the effective `skipGenerate` list (the configured list, or the default `[1]`), in list order, instead of a fixed `processorID: 1`. Additional pre-processors from `cluster.preProcessors` SHALL render as `extraPreDefaults` exactly as before.

#### Scenario: Ingest mode with a configured skipGenerate list (finalize success)
- **GIVEN** an ingest-mode values file (`tests/files/values.extract.ingest.yaml`, which also sets `cluster.preProcessors: [{processorId: 13, type: extract}]`) and `cluster.processors.skipGenerate: [4]`
- **WHEN** the chart renders `config.yaml`
- **THEN** `processors.skipGenerate` is `[4]` and `processors.extraPostDefaults` holds one entry with `processorID: 4` and `type: skip-generate`
- **AND** no `extraPostDefaults` entry with `processorID: 1` renders, and `extraPreDefaults` still holds `processorID: 13`, `type: extract`

### Requirement: Omitting cluster.processors renders today's processor configuration
When `cluster.processors` is absent or empty, the rendered `processors:` block, the `extraPreDefaults` entries, and the ingest-mode `extraPostDefaults` entry SHALL be byte-identical to the chart before this change.

#### Scenario: Existing snapshots stay unchanged (finalize success)
- **WHEN** the full helm-unittest suite runs through `.build/bin/validate-helm.sh` without `cluster.processors` in any existing fixture
- **THEN** every committed snapshot under `src/groundx/tests/__snapshot__/` matches with no update, including the `config.yaml` renders of the default, ingest (`extract.ingest`) and `cluster.preProcessors` fixtures
- **AND** no snapshot file differs from the merge base of the feature branch and `origin/0.2.8`

#### Scenario: Matches the 0.2.7 render of the same fixtures (finalize success)
- **GIVEN** the fixtures under `src/groundx/tests/files/` at commit `07d332fc6c` that render successfully at that commit
- **WHEN** each fixture is rendered at `07d332fc6c` and at the feature branch tip without `cluster.processors`
- **THEN** the `processors` mapping, including `extraPreDefaults` and `extraPostDefaults`, is equal in both renders
- **AND** this differential is run at verify time with named-field `yq` comparisons and its output saved outside the repository, not committed as a script
