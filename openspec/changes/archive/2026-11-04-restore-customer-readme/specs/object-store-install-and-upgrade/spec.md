## MODIFIED Requirements

### Requirement: Store wording names AIStor as the default and S4 as an option

`sample.values.yaml` SHALL reference an existing storage credentials Secret instead of inline `file.username` or `file.password` and SHALL contain no `minio` text. `src/groundx/values/README.md` and its byte-identical `helm/` copy SHALL list `aistor` and `s4` folders and no `minio` folder. `docs/agents/repository-guide.md`, `ARCHITECTURE_NOTES.md`, `service.yaml`, and `openspec/config.yaml` SHALL describe the store as MinIO AIStor (default), AWS S3, or S4, SHALL list the AIStor Helm repository instead of the community MinIO one, and SHALL describe `minio123` only where it still ships (the unchanged Chainguard sample values).

#### Scenario: Sample credentials are placeholders (reject before state)
- **WHEN** the storage credentials in `sample.values.yaml` are read
- **THEN** `fileAccess.storageCredentialsSecretName` is set, inline `.file.username` and `.file.password` are absent, and the file contains no `minio` text

#### Scenario: Repo docs no longer name community MinIO as the store (finalize success)
- **WHEN** the four repo docs are searched
- **THEN** none contains ``MinIO `minio123` `` or `percona, minio, strimzi`, `service.yaml` contains no `minio-s3` or `percona/minio/`, and `ARCHITECTURE_NOTES.md`, `service.yaml`, and `openspec/config.yaml` each name AIStor and S4
- **AND** both `values/README.md` copies list `aistor` and `s4`, list no `minio` folder, and are byte-identical
