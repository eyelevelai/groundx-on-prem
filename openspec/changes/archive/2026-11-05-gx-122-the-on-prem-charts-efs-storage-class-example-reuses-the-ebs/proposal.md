## Why

The EBS and EFS storage-class example values files both set `storageClassName: eyelevel-pv`. A StorageClass name is cluster-wide and its provisioner is immutable, so a cluster cannot hold a block-storage class and a file-storage class created from the two examples: the second install collides. GX-122 gives the EFS example its own name so both classes can coexist.

## What Changes

- Set `storageClassName: eyelevel-efs` (line 1) in `src/groundx/prereqs/storageclass/values.efs.example.yaml` and the byte-identical mirror `helm/prereqs/storageclass/values.efs.example.yaml`. The EBS example keeps `eyelevel-pv`.
- Add one name assertion for the EFS example to `STORAGE_EXAMPLES["efs"]` in `.build/bin/verify-storage-contract.py`, written first so it fails on the unchanged example.
- Add one clause to the EKS/EFS bullet in `docs/upgrades.md`: new installs from the EFS example set `cluster.pvClass: eyelevel-efs`; existing EFS releases keep their current `storageClassName`.
- No template, values schema, snapshot, `setup-eks` Terraform, or EBS/Azure Files/GKE Filestore example changes.

Blast radius: the example file is a sample, not a default; no chart template or default value reads it. Only an operator who installs the EFS storage-class release from this example gets the new class name. Existing EFS releases are unaffected on upgrade because the clause tells them to keep their current name (renaming would orphan the class the app chart's `cluster.pvClass` still points at, and a PVC `storageClassName` is immutable). Environments: none redeployed by this change; no stateful resource is touched. Rollback: revert the commit; no cluster state depends on the example text.

Open design questions: none.

## Capabilities

### New Capabilities
- `storageclass-example-names`: the EFS storage-class example uses a name distinct from the EBS example, the source and `helm/` mirror agree, and the storage contract verifier asserts the EFS name.

### Modified Capabilities

## Impact

- `src/groundx/prereqs/storageclass/values.efs.example.yaml` and `helm/prereqs/storageclass/values.efs.example.yaml` (line 1).
- `.build/bin/verify-storage-contract.py` (`STORAGE_EXAMPLES["efs"]`); the existing `verify_mirrors()` already enforces the src/`helm/` match.
- `docs/upgrades.md` (EKS/EFS bullet).
- Gate: `.build/bin/validate-helm.sh` run by the pre-push hook.
