# extract-bedrock-storage Specification

## Purpose
TBD - created by archiving change gx-88-trace-capture-and-bedrock-image-bytes. Update Purpose after archive.
## Requirements
### Requirement: The chart renders the Bedrock extract agent with every file storage type

`groundx.extract.agent.validateImageSettings` in `src/groundx/templates/_helpers/app/extract-agent.tpl` and in its byte-identical copy `helm/templates/_helpers/app/extract-agent.tpl` SHALL NOT fail a render because `extract.agent.serviceType` is `bedrock` and the extract file storage type is something other than `s3`. The check that did so (the `$serviceType` lookup and the `if`/`fail` block "extract.agent.serviceType bedrock requires AWS S3 file storage") is removed from both copies, and nothing else in either template changes. Validated by helm-unittest cases in the existing suite `src/groundx/tests/extract_test.yaml` (assertion-only, no snapshot), run with helm v3.19.0, and by `.build/bin/validate-helm.sh`.

#### Scenario: Bedrock renders on the chart's default storage (finalize success)
- **GIVEN** `src/groundx/tests/files/values.disabled.yaml` with `extract.enabled: true`, `extract.agent.enabled: true`, `extract.agent.serviceType: bedrock`, and no storage settings
- **WHEN** helm-unittest renders `templates/resources/extract-config-py.yaml`
- **THEN** the render does not fail
- **AND** `stringData["config.py"]` contains `service="bedrock"`
- **AND** its `type=` value is the chart's default storage type, the value `groundx.file.storageType` returns when `file.existing.serviceType` is unset, not `s3`

#### Scenario: Bedrock renders on s4 storage (finalize success)
- **GIVEN** the same values plus `file.existing.serviceType: s4` and `file.existing.url: http://s4.eyelevel.svc.cluster.local:7480`
- **WHEN** helm-unittest renders `templates/resources/extract-config-py.yaml`
- **THEN** the render does not fail, and `stringData["config.py"]` contains `service="bedrock"` and `type="s4"`

#### Scenario: Bedrock on s3 storage still renders (finalize success)
- **GIVEN** the existing case "bedrock extract config renders service and preserves configured transport" (`extract.file.serviceType: s3`) and the existing Bedrock cases that render with `s3` storage
- **WHEN** the suite runs
- **THEN** each passes unchanged, and `stringData["config.py"]` still contains `type="s3"`

#### Scenario: Both template copies drop the check and stay identical (finalize success)
- **WHEN** `cmp` compares `src/groundx/templates/_helpers/app/extract-agent.tpl` with `helm/templates/_helpers/app/extract-agent.tpl`, and both are searched for `requires AWS S3 file storage`
- **THEN** the files are identical and neither contains the text

#### Scenario: Inputs that rendered before render byte-identically (finalize success)
- **GIVEN** the chart at commit `b67b3ded` (before the template edit) and this change's chart, for both `src/groundx` and `helm`
- **WHEN** both are rendered with no values file, `values/minikube/values.yaml`, `values/values.existing.yaml`, `values/values.aws.services.yaml`, `mode=ingest`, `mode=search`, `values/extract/values.yaml`, and `values/extract/values.yaml` with Bedrock on `s3` storage
- **THEN** each pair of renders is byte-identical
- **AND** `.build/bin/validate-helm.sh` run with helm v3.19.0 passes, no file under `src/groundx/tests/__snapshot__/` differs from `b67b3ded` or is untracked, and neither `values.schema.json` differs from `b67b3ded`

### Requirement: Removing the Bedrock storage check keeps every other image-setting check

Invariant: an image-setting combination that `validateImageSettings` rejected for any reason other than Bedrock with storage other than `s3` SHALL still fail the render, now also when Bedrock runs on storage other than `s3`. The helper's long-edge check ("extract.agent.minLongEdgePx must be less than or equal to extract.agent.targetLongEdgePx") is the only check in the helper that values passing `values.schema.json` can reach. The schema already rejects an `imageTransport` outside its enum, a `maxRequestImages` below 1, and a `jpegQualities` item outside 1 to 95 before any template runs. The suite therefore carries the long-edge case as its failing input for the helper. Helm stops at the first template that fails, which for extract agent settings is `templates/resources/extract-supervisord-conf.yaml`, so the case asserts against that template.

#### Scenario: A minimum long edge above the target still fails with Bedrock on non-s3 storage (reject before state)
- **GIVEN** `src/groundx/tests/files/values.disabled.yaml` with `extract.enabled: true`, `extract.agent.enabled: true`, `extract.agent.serviceType: bedrock`, `extract.agent.targetLongEdgePx: 899`, `extract.agent.minLongEdgePx: 900`, and the chart's default storage
- **WHEN** helm-unittest renders `templates/resources/extract-supervisord-conf.yaml`
- **THEN** the render fails with exactly "extract.agent.minLongEdgePx must be less than or equal to extract.agent.targetLongEdgePx"
- **AND** no manifest is produced, so a change that removed the helper's call from `groundx.extract.agent.settings` (the path `extract-supervisord-conf.yaml` renders through) instead of only the Bedrock check would fail this case

#### Scenario: Valid image settings with Bedrock on non-s3 storage are not blocked (finalize success)
- **GIVEN** the Bedrock cases on the chart's default storage and on `s4` storage above, which use the default image settings (`targetLongEdgePx` 1000, `minLongEdgePx` 900)
- **WHEN** the suite runs
- **THEN** both renders succeed, so the helper does not over-block a valid Bedrock configuration on storage other than `s3`

