## Goals / Non-Goals

- Goal: the EFS example no longer collides with the EBS example on StorageClass name.
- Non-goals: chart templates, values schema, snapshots, `setup-eks` Terraform, and the EBS/Azure Files/GKE Filestore examples. No migration of existing EFS releases.

## Decisions

- Rename only the example's `storageClassName` to `eyelevel-efs`. The example is a sample that no template or default reads (see proposal.md), so no compatibility mechanism is needed; the `docs/upgrades.md` clause covers existing releases.
- Edit `src/groundx/` and copy byte-identically to `helm/`; the existing `verify_mirrors()` in `.build/bin/verify-storage-contract.py` already enforces the match, so no new mirror check is added.
- Add one regex to `STORAGE_EXAMPLES["efs"]["must"]` (`name:\s+eyelevel-efs`), matched against the rendered StorageClass like the existing entries. It is written first and fails on the unchanged example.
- Doc clause goes in the existing EKS/EFS bullet of `docs/upgrades.md`; no new section.
