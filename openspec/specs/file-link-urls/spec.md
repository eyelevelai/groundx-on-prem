# file-link-urls Specification

## Purpose
Optional chart values that set the file link host (`upload.baseUrl`) and a second GroundX link host (`uploadGroundx`) without the file-access gateway.
## Requirements
### Requirement: A separate file link host without the gateway
The chart SHALL accept an optional `file.publicUrl` (an `http` or `https` scheme, a hostname of letters, digits, dots and hyphens, and an optional port, with no path, credentials, query or fragment, validated by the schema pattern `^$|^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?$`; `file.signingEndpoint` keeps its own pattern `^$|^https?://[^/@?#]+$`). When it is set and `fileAccess.enabled` is false, the rendered `config.yaml` `upload.baseUrl` SHALL equal `file.publicUrl`. `upload.baseDomain` and `upload.bucketUrl` SHALL keep the storage host the chart derives today, for S3, MinIO and S4 storage alike, so storage access and stored-link recognition by bucket URL are unchanged. When it is empty or absent, `upload.baseUrl` SHALL render exactly as before.

#### Scenario: Link host with S3 storage on a third host (finalize success)
- **GIVEN** `fileAccess.enabled: false`, S3 storage with `file.existing.url: https://gx-test-bucket.s3.us-west-2.amazonaws.com`, and `file.publicUrl: https://upload.eyelevel.ai`
- **WHEN** the chart renders `config.yaml`
- **THEN** `upload.baseUrl` is `https://upload.eyelevel.ai`
- **AND** `upload.baseDomain` is `gx-test-bucket.s3.us-west-2.amazonaws.com` and `upload.bucketUrl` is `https://gx-test-bucket.s3.us-west-2.amazonaws.com`, not the link host and not an in-cluster MinIO default

#### Scenario: Link host with chart-deployed MinIO (finalize success)
- **GIVEN** chart-deployed MinIO storage and `file.publicUrl: https://files.customer.example.com`
- **WHEN** the chart renders `config.yaml`
- **THEN** `upload.baseUrl` is `https://files.customer.example.com`
- **AND** `upload.baseDomain` and `upload.bucketUrl` keep the in-cluster MinIO host (`minio.eyelevel.svc.cluster.local`), and `upload.service` stays `minio`

### Requirement: An optional GroundX alias section
The chart SHALL accept an optional `file.groundxPublicUrl` with the same schema pattern as `file.publicUrl`. When it is set and `fileAccess.enabled` is false, the rendered `config.yaml` SHALL contain an `uploadGroundx` section whose `baseUrl` equals `file.groundxPublicUrl` and whose every other field (`signingEndpoint` when `file.signingEndpoint` is set, `baseDomain`, `bucket`, `bucketUrl`, `id`, `region`, `secret`, `service`, `ssl`, `token`) equals the corresponding `upload` field, with the same presence rules. When it is empty or absent, no `uploadGroundx` section SHALL render, so cashbot-go keeps falling back to `upload` for GroundX links.

#### Scenario: Link host plus alias without the gateway (finalize success)
- **GIVEN** `fileAccess.enabled: false`, S3 storage on `https://gx-test-bucket.s3.us-west-2.amazonaws.com` with fixture storage credentials and a region, `file.publicUrl: https://upload.eyelevel.ai` and `file.groundxPublicUrl: https://upload.groundx.ai`
- **WHEN** the chart renders `config.yaml`
- **THEN** `upload.baseUrl` is `https://upload.eyelevel.ai` and `uploadGroundx.baseUrl` is `https://upload.groundx.ai`
- **AND** both `bucketUrl` fields are `https://gx-test-bucket.s3.us-west-2.amazonaws.com`, and `uploadGroundx.baseDomain`, `bucket`, `id`, `region`, `secret`, `service` and `ssl` equal the `upload` values

#### Scenario: No alias renders no alias section (finalize success)
- **GIVEN** `file.publicUrl` set and `file.groundxPublicUrl` unset
- **WHEN** the chart renders `config.yaml`
- **THEN** no `uploadGroundx` key appears anywhere in `config.yaml`

### Requirement: Layout reads files linked on either link host from storage
When `file.publicUrl` or `file.groundxPublicUrl` is set and `fileAccess.enabled` is false, the layout `config.py` `uploadReplaceURL` SHALL render as a list: the storage bucket URL it renders today, then each set link host followed by the same bucket suffix. Layout then reads a file whose URL starts with a link host through storage credentials instead of an unauthenticated download, which a private bucket refuses. When neither key is set, `uploadReplaceURL` SHALL render the single bucket URL string exactly as before.

#### Scenario: Both link hosts with chart-deployed MinIO (finalize success)
- **GIVEN** `fileAccess.enabled: false`, MinIO storage on `minio.eyelevel.svc.cluster.local`, `file.publicUrl: https://files.customer.example.com` and `file.groundxPublicUrl: https://upload.groundx.ai`
- **WHEN** the chart renders the layout `config.py`
- **THEN** `uploadReplaceURL` is the list `"http://minio.eyelevel.svc.cluster.local/eyelevel/"`, `"https://files.customer.example.com/eyelevel/"`, `"https://upload.groundx.ai/eyelevel/"`

### Requirement: The link host keys are rejected when the file-access gateway is enabled
With `fileAccess.enabled: true`, a non-empty `file.publicUrl` or `file.groundxPublicUrl` SHALL fail the render through `groundx.fileAccess.validate`. With the gateway on, `fileAccess.publicUrl` owns `upload.baseUrl`, and cashbot-go checks the gateway against `uploadGroundx` whenever that section has a base URL and fails closed when the check does not pass. The `file.groundxPublicUrl` message SHALL NOT present `fileAccess.trustedOrigins` as a replacement. The gateway's rendering and validation SHALL otherwise stay unchanged.

#### Scenario: Gateway on with a link host fails the render (reject before state)
- **GIVEN** the gateway fixture `tests/files/values.file-access.yaml` and `file.publicUrl: https://downloads.example.com`
- **WHEN** the chart renders
- **THEN** rendering fails with `file.publicUrl is not supported when fileAccess is enabled; remove it and set the file link host with fileAccess.publicUrl`
- **AND** no manifest is produced

#### Scenario: Gateway on with a GroundX alias fails the render (reject before state)
- **GIVEN** the gateway fixture and `file.groundxPublicUrl: https://upload.groundx.ai`
- **WHEN** the chart renders
- **THEN** rendering fails with `file.groundxPublicUrl is not supported when fileAccess is enabled; a second file link host requires fileAccess.enabled false`
- **AND** the message does not mention `fileAccess.trustedOrigins`

#### Scenario: Gateway on without the new keys still renders (must not block)
- **GIVEN** the gateway fixture with `file.publicUrl` and `file.groundxPublicUrl` left at their empty defaults
- **WHEN** the existing gateway render cases in `tests/file_settings_test.yaml` run
- **THEN** they pass unchanged, including "private gateway uses separate storage and native signing endpoints"

#### Scenario: Gateway off with both keys renders (must not block)
- **GIVEN** `fileAccess.enabled: false` and both keys set
- **WHEN** the chart renders
- **THEN** rendering succeeds as in "Link host plus alias without the gateway"

### Requirement: Omitting both link keys leaves the upload configuration unchanged
When neither `file.publicUrl` nor `file.groundxPublicUrl` is set, the rendered `upload` section SHALL be byte-identical to the chart before this change and no `uploadGroundx` section SHALL render. The `src/groundx` chart and the `helm/` mirror SHALL carry byte-identical templates, `values.yaml` and `values.schema.json`.

#### Scenario: Existing snapshots stay unchanged (finalize success)
- **WHEN** `.build/bin/validate-helm.sh` runs with Helm v3.19.0
- **THEN** every committed snapshot, which includes the full `config.yaml` of the default, existing-storage, cloud and gateway-off fixtures, matches with no update
- **AND** the template, `values.yaml` and `values.schema.json` mirror comparisons pass

#### Scenario: Matches the 0.2.7 render of the same fixtures (finalize success)
- **GIVEN** the fixtures under `src/groundx/tests/files/` at commit `07d332fc6c` that render successfully at that commit
- **WHEN** each fixture is rendered at `07d332fc6c` and at the feature branch tip
- **THEN** the `upload` mapping is equal in both renders and the tip render has no `uploadGroundx` key
- **AND** this differential is run at verify time with named-field `yq` comparisons and its output saved outside the repository, not committed as a script

