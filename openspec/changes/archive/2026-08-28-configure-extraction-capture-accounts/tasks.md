# Tasks

- [x] Add failing Helm tests for default, configured, and invalid allowlist values.
- [x] Add the source values, schema, and ConfigMap rendering.
- [x] Sync the same files into the published Helm mirror.
- [x] Regenerate snapshots and run `.build/bin/validate-helm.sh`.
- [x] Review the rendered production diff, deploy the approved account to the Helm-managed services, and verify rollout health.
- [x] Deploy the same approved account through Cashbot's hosted config and Lambda release path, then verify the effective hosted allowlist.
- [x] Run the four protected extraction cases in parallel and verify all temporary hosted resources were removed.
- [x] Archive this change after strict validation.
