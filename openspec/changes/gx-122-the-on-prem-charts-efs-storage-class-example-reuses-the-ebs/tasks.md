## 1. Rename the EFS example (verifier assertion first)

- [x] 1.1 Assert the EFS StorageClass name in `STORAGE_EXAMPLES["efs"]` (RED), then set `storageClassName: eyelevel-efs` in `src/groundx/prereqs/storageclass/values.efs.example.yaml`
  check: python3 .build/bin/verify-storage-contract.py
- [x] 1.2 Copy the example byte-identically to `helm/prereqs/storageclass/values.efs.example.yaml`
  check: grep -qx 'storageClassName: eyelevel-efs' helm/prereqs/storageclass/values.efs.example.yaml && cmp src/groundx/prereqs/storageclass/values.efs.example.yaml helm/prereqs/storageclass/values.efs.example.yaml

## 2. Document

- [x] 2.1 Add one clause to the EKS/EFS bullet in `docs/upgrades.md`: new installs set `cluster.pvClass: eyelevel-efs`; existing EFS releases keep their current `storageClassName`
  check: grep -q 'cluster.pvClass: eyelevel-efs' docs/upgrades.md

See workspace `openspec/changes/gx-122-the-on-prem-charts-efs-storage-class-example-reuses-the-ebs/tasks.md` for cross-service coordination and deferred items.
