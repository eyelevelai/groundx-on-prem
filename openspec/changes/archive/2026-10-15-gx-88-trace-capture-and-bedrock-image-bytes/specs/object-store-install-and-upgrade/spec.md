## MODIFIED Requirements

### Requirement: Community MinIO sample values stop shipping while installed stores keep working

The community MinIO operator and tenant sample values SHALL no longer ship: `src/groundx/values/minio/` and `helm/values/minio/` are deleted. Installed MinIO tenants (separate Helm releases), the `minio` storage-type value, the chart's default store hosts and credentials comments, every chart template other than the Bedrock storage check that capability `extract-bedrock-storage` removes, every default, the helm-unittest snapshots, and the Chainguard MinIO seeds SHALL remain unchanged.

#### Scenario: Legacy sample files are gone and nothing points at them (finalize success)
- **WHEN** the working tree is checked
- **THEN** neither `values/minio/` directory exists and no file outside `openspec/changes/`, `openspec/specs/`, `bin/operator`, and `terraform/groundx-operator/` contains `values/minio/`

#### Scenario: Existing installs render the same objects (finalize success)
- **GIVEN** the base commit's chart with this change's `Chart.yaml` copied in, and this change's chart
- **WHEN** both are rendered with no values file (bundled store), `values/minikube/values.yaml`, `values/values.existing.yaml` (`serviceType: minio`), `values/values.aws.services.yaml`, `mode=ingest`, and `mode=search`, for both `src/groundx` and `helm`
- **THEN** each pair of renders is byte-identical
