## ADDED Requirements

### Requirement: Chart renders inlineImages only when the engine's values set it to true

The chart SHALL render `inlineImages: true` in an engine block of the generated `config.yaml` when, and only when, that engine's own `engines.<name>.inlineImages` value is the boolean `true`. The engine loop of `templates/resources/config-yaml.yaml` SHALL decide this from the engine's own value alone. It SHALL NOT read the storage type, `fileAccess.enabled`, the engine's `service` or its `baseUrl`, and SHALL NOT add the key to the shared engine helpers, so the other readers of `groundx.engines` never see a derived value. An engine whose value is unset, `false`, or not a boolean SHALL render no `inlineImages` key, and the key SHALL be placed after `baseURL` and before the `maxImages` position.

#### Scenario: Local engine on s3 storage with no inlineImages value renders no key

- **POLARITY** skip unrelated repair path
- **GIVEN** `file.existing.url` is set, `file.existing.serviceType` is `s3`, no `engines` section is set, so the implicit default engine is the in-cluster summary-api, and no `inlineImages` value exists anywhere in the values
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the config's `upload` block shows `service: s3` and the engine block shows `service: eyelevel` with the in-cluster `baseURL`
- **AND** no `inlineImages` key appears anywhere in the config, so a storage-type or locality rule would make this scenario fail.

#### Scenario: Operator true on the local s3 engine renders the key

- **POLARITY** finalize success
- **GIVEN** storage type `s3` and `engines.default` declared with an `engineId` and `inlineImages: true`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the engine block shows `service: eyelevel` and the in-cluster `baseURL`, followed on the next line by exactly one `inlineImages: true`.

#### Scenario: Operator true on an engine outside the cluster on in-cluster storage renders the key

- **POLARITY** finalize success
- **GIVEN** no `file.existing.url` is set, which renders storage type `minio`, and `engines.default` is an `openai` engine with `inlineImages: true`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the config's `upload` block shows `service: minio` and the engine block shows `service: openai`, followed by exactly one `inlineImages: true`
- **AND** the key appears although neither the storage type nor the engine is the chart's own, so an operator can opt in on any engine.

#### Scenario: Operator false renders no key

- **POLARITY** skip unrelated repair path
- **GIVEN** `engines.default` has `inlineImages: false` and a named engine `other` has `inlineImages: true`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** only the `other` engine block shows `inlineImages: true`; the default engine block has no `inlineImages` key, so `false` renders the same as never setting the value.

### Requirement: Values schema accepts a boolean inlineImages and rejects other types

`values.schema.json` SHALL declare `engines.default.inlineImages` as a boolean. A value of any other type SHALL be rejected by schema validation before any template renders.

#### Scenario: String value is rejected before render

- **POLARITY** reject before state
- **GIVEN** `engines.default.inlineImages` is the string `"yes"`
- **WHEN** the chart renders
- **THEN** rendering fails with an error naming `engines/default/inlineImages` and the type error `got string, want boolean`
- **AND** no `config.yaml` is produced.

### Requirement: Installs that do not set inlineImages render exactly what the base branch renders

For every install whose values do not set `inlineImages` to true on any engine, the chart SHALL render the same `config.yaml`, and therefore the same `config-hash` annotations, as the chart base branch. The committed snapshots `golang_test.yaml.snap`, `metrics_test.yaml.snap` and `resources_test.yaml.snap` SHALL equal the base branch's, and SHALL be checked through `.build/bin/validate-helm.sh` and never regenerated with `helm unittest -u`.

#### Scenario: Snapshots equal the base branch and the gate passes

- **POLARITY** skip unrelated repair path
- **GIVEN** the chart with this change and helm v3.19.0
- **WHEN** `.build/bin/validate-helm.sh` runs without `-u`
- **THEN** the gate passes
- **AND** `git diff` of the three snapshot files against the base branch is empty, so no install that leaves the value unset gets a new `config-hash` and no Deployment rolls for it.

#### Scenario: Derived-default remnant is caught

- **POLARITY** reject before state
- **GIVEN** a template that still renders `inlineImages: true` for the in-cluster engine on `s3` storage without any operator value
- **WHEN** the gate runs against the committed snapshots
- **THEN** the gate fails on the `config-hash` of the labels that render `s3` storage, so the remnant cannot ship green.

### Requirement: helm/ mirrors the changed chart files byte for byte

`helm/templates/resources/config-yaml.yaml`, `helm/values.yaml` and `helm/values.schema.json` SHALL be byte-identical to their `src/groundx` counterparts. `src/groundx` is edited first.

#### Scenario: Mirrors are identical

- **POLARITY** finalize success
- **GIVEN** the three files edited in `src/groundx`
- **WHEN** each is compared with its `helm/` copy
- **THEN** the two copies of each file are identical.

### Requirement: values.yaml documents the setting in comments only

`values.yaml` SHALL carry a commented `engines` example for `inlineImages`, in plain English for operators. It SHALL state, using a real example engine, that the setting is off unless an operator sets it, that a page the worker cannot read fails the document, that setting `engines` replaces the built-in engine so `default` must repeat the built-in settings, and that `true` on an engine outside the cluster sends page images to that engine. Every added line SHALL be a comment or blank, so no rendered output changes.

#### Scenario: Added values.yaml lines are documentation only

- **POLARITY** skip unrelated repair path
- **GIVEN** the diff of `src/groundx/values.yaml` against the base branch
- **WHEN** each added line is inspected
- **THEN** every added line is a comment or blank, and the added text names `inlineImages`, `engineId` and the document-failure consequence
- **AND** it contains no statement that the chart turns the setting on by itself.

### Requirement: An older worker image tolerates the rendered key during rollout

The chart SHALL treat the rendered key as additive: a summary-client image that predates the setting SHALL keep working when the chart renders `inlineImages: true`, because the application decodes its `config.yaml` without strict mode.

#### Scenario: Backward compatibility during rollout

- **POLARITY** accept and enqueue
- **GIVEN** an operator sets `inlineImages: true` and `helm upgrade` runs while the summary-client image is still one that does not read the key
- **WHEN** the worker starts and loads `config.yaml`
- **THEN** the unknown key is ignored and the worker behaves as before
- **AND** the setting takes effect only after a summary-client image that reads it is running (validated by source read of the decoder, not by a chart test; see `design.md`).
