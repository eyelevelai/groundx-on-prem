# Tasks

- [x] Add failing Helm tests for default, configured, and invalid allowlist values.
- [x] Add the source values, schema, and ConfigMap rendering.
- [x] Sync the same files into the published Helm mirror.
- [x] Regenerate snapshots and run `.build/bin/validate-helm.sh`.
- [ ] Review the rendered production diff, deploy the approved account, and verify rollout health.
- [ ] Run protected extraction certification, remove temporary resources, and archive this change.
