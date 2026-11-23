# storageclass-example-names Specification

## Purpose
TBD - created by archiving change gx-122-the-on-prem-charts-efs-storage-class-example-reuses-the-ebs. Update Purpose after archive.
## Requirements
### Requirement: storageclass-example-names

The EFS storage-class example SHALL set `storageClassName: eyelevel-efs`, distinct from the EBS example's `eyelevel-pv`, so a cluster can hold both classes. The `helm/` mirror SHALL be byte-identical to the `src/groundx/` example, and the storage contract verifier SHALL assert the EFS name. The EBS, Azure Files and GKE Filestore examples SHALL be unchanged.

#### Scenario: EFS example renders its own class name
- **WHEN** the storage-class chart is rendered with `values.efs.example.yaml`
- **THEN** the StorageClass is named `eyelevel-efs`
- **AND** it is not named `eyelevel-pv` (finalize success; the opposite name must not be accepted).

#### Scenario: Verifier rejects the shared name
- **WHEN** the EFS example still sets `storageClassName: eyelevel-pv`
- **THEN** `.build/bin/verify-storage-contract.py` exits non-zero reporting the missing EFS name (reject before state).

#### Scenario: Mirror drift is caught
- **WHEN** the `helm/` copy of the EFS example differs from the `src/groundx/` copy
- **THEN** the verifier's mirror check fails.

#### Scenario: Existing EFS releases keep their name
- **WHEN** an operator upgrades an existing EFS release
- **THEN** `docs/upgrades.md` tells them to keep their current `storageClassName`, so the PVC class `cluster.pvClass` points at is not orphaned (skip unrelated repair path; no template or default changes).

