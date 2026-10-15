## MODIFIED Requirements

### Requirement: The chart documents `s4` as a storage type without changing any default

The `file.existing.serviceType` comment at `src/groundx/values.yaml:74` and `helm/values.yaml:74` SHALL list `s4` with `minio` and `s3`. The parsed content of both `values.yaml` files SHALL equal the base commit's, so no default changes. No chart template changes other than removing the Bedrock storage check (capability `extract-bedrock-storage`): the chart already passes `file.existing.serviceType` through unchanged to cashbot-go (`upload.service`), the ai-server layout workers (`uploadType`), and the extract services (`type`), and keeps the bucket in the path for every value other than `s3`.

#### Scenario: Comment lists s4 and defaults stay the same (finalize success)
- **WHEN** both `values.yaml` files are read
- **THEN** each `# serviceType:` comment line names `s4`
- **AND** `yq -o=json` of each file equals `yq -o=json` of the same file at the merge base with `origin/main`

#### Scenario: s4 reaches every consumer unchanged (finalize success)
- **GIVEN** `file.existing.url=http://s4.eyelevel.svc.cluster.local:7480`, `file.existing.serviceType=s4`, no region, and `extract.enabled=true`
- **WHEN** the chart renders in `mode` `all` and `ingest`
- **THEN** the cashbot-go config has `service: s4`, the layout config has `uploadType="s4"` and `uploadURL="http://s4.eyelevel.svc.cluster.local:7480/eyelevel/"`, and the extract config has `type="s4"`
- **AND** storage wait init containers run `nc -z s4.eyelevel.svc.cluster.local 7480`
- **AND** nothing in the render contains `amazonaws`
- **AND** the helm-unittest case "s4 storage type reaches cashbot-go, layout, and extract unchanged" in `src/groundx/tests/extract_test.yaml`, which renders the same values in the default `mode`, asserts the cashbot-go `service: s4`, the layout `uploadType="s4"` and `uploadURL`, and the extract `type="s4"` and `url="http://s4.eyelevel.svc.cluster.local:7480/eyelevel/"`; the `ingest` mode, `nc -z`, and `amazonaws` checks stay covered by the render check

### Requirement: Chart version 0.2.8 is the minimum for s4

`version` and `appVersion` in `src/groundx/Chart.yaml` and `helm/Chart.yaml` SHALL be `0.2.8`, so default image tags select the service releases that implement `s4`. Templates SHALL NOT change other than the removal of the Bedrock storage check (capability `extract-bedrock-storage`), and defaults and snapshots SHALL NOT change. `openspec/config.yaml` SHALL NOT hard-code the chart version.

#### Scenario: Version bump changes nothing but the version (finalize success)
- **GIVEN** both `Chart.yaml` files at `0.2.8`
- **WHEN** the base commit's chart, with this change's `Chart.yaml` copied in, and this change's chart are rendered with the same inputs listed under the object-store capability's "Existing installs render the same objects" scenario
- **THEN** every pair is byte-identical
- **AND** `.build/bin/validate-helm.sh` run with helm v3.19.0 passes
- **AND** no file under `src/groundx/tests/__snapshot__/` differs from the merge base or is untracked
- **AND** `openspec/config.yaml` no longer contains `Chart version: 0.2.7`
