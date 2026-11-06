## ADDED Requirements

### Requirement: Derived default marks only the chart's own engine on s3 storage

The chart SHALL render `inlineImages: true` in an engine block of the generated `config.yaml` when, and only when, `groundx.engine.create` is true for that engine and `groundx.file.storageType` is exactly the lowercase string `s3`, unless the operator sets `inlineImages` on that engine (see the override requirement). The derived default SHALL be computed in `config-yaml.yaml`, SHALL NOT read `fileAccess.enabled`, and SHALL NOT add a key to the shared engine helpers, so the other readers of `groundx.engines` never see it.

#### Scenario: Local engine on s3 storage renders the flag

- **POLARITY** finalize success
- **GIVEN** `file.existing.url` is set, `file.existing.serviceType` is `s3`, and no `engines` section is set, so the implicit default engine is the in-cluster summary-api
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the config's `upload` block shows `service: s3`
- **AND** that engine block carries exactly one `inlineImages: true`, placed after `baseURL` and before the `maxImages` position.

#### Scenario: In-cluster MinIO and AIStor storage render no key

- **POLARITY** skip unrelated repair path
- **GIVEN** no `file.existing.url` is set, which renders storage type `minio` for both MinIO and in-cluster AIStor
- **WHEN** `templates/resources/config-yaml.yaml` renders with the local engine present
- **THEN** the config's `upload` block shows `service: minio`
- **AND** no `inlineImages` key appears anywhere in the config.

#### Scenario: S4 storage renders no key

- **POLARITY** skip unrelated repair path
- **GIVEN** `file.existing.serviceType` is `s4`
- **WHEN** `templates/resources/config-yaml.yaml` renders with the local engine present
- **THEN** the config's `upload` block shows `service: s4`
- **AND** no `inlineImages` key appears.

#### Scenario: Remote eyelevel engine on s3 storage renders no key

- **POLARITY** skip unrelated repair path
- **GIVEN** storage type `s3` and an engine with service `eyelevel` whose `baseUrl` is not the in-cluster summary-api URL
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** that engine block shows its remote `baseURL`
- **AND** no `inlineImages` key appears.

#### Scenario: OpenAI engine on s3 storage renders no key (catches a storage-only rule)

- **POLARITY** skip unrelated repair path
- **GIVEN** storage type `s3` and an engine with service `openai`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the config's `upload` block shows `service: s3`
- **AND** the engine block shows `service: openai` and no `inlineImages` key appears.

### Requirement: Operator override wins when it is a boolean

An operator-set `engines.<name>.inlineImages` that is a boolean SHALL decide the engine's rendering on any engine: `true` renders `inlineImages: true`, and `false` omits the key (the rendered config shows no `inlineImages` for that engine, which the consumer reads as off). A value that is absent, null, or not a boolean SHALL leave the derived default in force.

#### Scenario: Operator false turns the derived default off

- **POLARITY** skip unrelated repair path
- **GIVEN** storage type `s3`, a local engine declared as `engines.default` with an `engineId`, and `engines.default.inlineImages: false`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the config's `upload` block shows `service: s3` and the engine block shows the in-cluster `baseURL`
- **AND** no `inlineImages` key appears anywhere in the config.

#### Scenario: Operator true on a non-local engine renders the flag

- **POLARITY** accept and enqueue
- **GIVEN** storage type `s3`, an engine with service `openai`, and `engines.default.inlineImages: true`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** that engine block carries `inlineImages: true`.

#### Scenario: Opting out needs the full engine block

- **POLARITY** reject before state
- **GIVEN** an install with no `engines` section and only `engines.default.inlineImages: false` set
- **WHEN** Helm validates the values
- **THEN** validation fails with `missing property 'engineId'` and nothing renders, because setting `engines` replaces the implicit default engine and the schema requires `engineId`.

### Requirement: Schema accepts a boolean and rejects any other type

`values.schema.json` SHALL accept `engines.default.inlineImages` as a boolean and SHALL reject any other type before any template renders. Engine names other than `default` remain unconstrained by the schema, as today.

#### Scenario: Helm validates a boolean inlineImages

- **POLARITY** accept and enqueue
- **GIVEN** values include `engines.default.inlineImages: true` or `false` with an `engineId`
- **WHEN** Helm validates the chart values schema
- **THEN** validation succeeds on both `src/groundx` and `helm`.

#### Scenario: Helm rejects a string inlineImages

- **POLARITY** reject before state
- **GIVEN** values include `engines.default.inlineImages: "yes"` as a string
- **WHEN** Helm validates the chart values schema
- **THEN** validation fails with `got string, want boolean` for `/engines/default/inlineImages`
- **AND** no manifest is rendered.

### Requirement: Installs outside the derived case render byte-identically

An install whose storage type is not `s3`, or whose engines are not the chart's own, and that sets no `inlineImages` override, SHALL render the same bytes as before this change on every template, and the change SHALL NOT add or remove any Kubernetes resource.

#### Scenario: Unflagged example installs are unchanged

- **POLARITY** skip unrelated repair path
- **GIVEN** the example values files for minikube, openshift, openai, existing, chainguard, and the extract OpenAI-engine install
- **WHEN** the whole chart renders from the merge base with `origin/main` and from the working tree
- **THEN** each pair of renders is byte-identical.

#### Scenario: A flagged example differs by the one added line

- **POLARITY** finalize success
- **GIVEN** the generated AWS services values file, which renders the local engine on s3
- **WHEN** `config-yaml.yaml` renders from the merge base and from the working tree
- **THEN** the only difference is one added line, `inlineImages: true`
- **AND** no line is removed.

#### Scenario: Chart renders the key before a compatible worker image is deployed

- **POLARITY** accept and enqueue
- **GIVEN** the chart renders `inlineImages: true` and the deployed summary-client image predates the worker change that reads it
- **WHEN** a document is summarized
- **THEN** that image sends requests exactly as before, because its config decode does not run in strict mode and an unknown key is not an error
- **AND** the chart alone is not the fix for GX-93.

### Requirement: Snapshot lines and config hashes change only where the local engine renders on s3

A committed snapshot line `inlineImages: true`, and a changed `config-hash` value, SHALL appear for a snapshot label if and only if that label renders the chart's own engine with storage type `s3`.

#### Scenario: A label that renders s3 with another engine stays unchanged (catches)

- **POLARITY** skip unrelated repair path
- **GIVEN** the `extract.oai` label renders `upload` service `s3` but its engine is `openai-base64`
- **WHEN** the snapshots are compared with the merge base
- **THEN** `extract.oai` gains no `inlineImages` line in the resources snapshot and keeps its `config-hash` in the golang and metrics snapshots
- **AND** every label that renders storage type `minio` is unchanged too.

#### Scenario: Labels that render the local engine on s3 gain the line and a new hash (must not block)

- **POLARITY** finalize success
- **GIVEN** the `aws`, `cloud`, `extract` and `extract.ingest` labels render the local engine on s3
- **WHEN** `.build/bin/validate-helm.sh` runs with helm v3.19.0
- **THEN** it passes with each of those labels showing `inlineImages: true` in the resources snapshot and the `config-hash` its own render produces in the golang and metrics snapshots
- **AND** the only changed snapshot lines against the merge base are `inlineImages: true` additions and `config-hash` replacements.

### Requirement: Mirror copies stay identical

Each of `templates/resources/config-yaml.yaml`, `values.yaml` and `values.schema.json` SHALL be byte-identical between `src/groundx` and `helm/`.

#### Scenario: Mirrored files match

- **POLARITY** finalize success
- **GIVEN** the three files are edited in `src/groundx` and copied to `helm/`
- **WHEN** the gate's `verify_mirrors()` runs and `cmp` compares the top-level `values.yaml` and `values.schema.json` pairs
- **THEN** every pair is identical.

### Requirement: values.yaml documents the setting without changing any render

`src/groundx/values.yaml` and `helm/values.yaml` SHALL carry a commented `engines` example that shows `engines.default.inlineImages`, states that setting `engines` replaces the implicit default engine so `engineId` is required, and warns that `true` on a remote engine sends the install's page-image bytes to that engine's `baseUrl`. The addition SHALL contain comment lines only.

#### Scenario: Example is documentation only

- **POLARITY** skip unrelated repair path
- **GIVEN** the commented example is added to both `values.yaml` copies
- **WHEN** the change is diffed against the merge base
- **THEN** every added line in `src/groundx/values.yaml` is a comment or blank line
- **AND** the committed `helm unittest` snapshots that render with `../values.yaml` still match.
