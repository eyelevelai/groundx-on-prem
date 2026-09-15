# Rollout

1. Verify AWS identity, pushed source, existing database clients, worker security group, and zero production managed-record allocations.
2. Create a new Studio-only administrator requiring TLS, CREATE USER, and database privileges with delegation only for gx-%-prod. Existing user passwords and schemas are untouched. Test the production provider against Studio before changing live settings.
3. Attach a dedicated security group allowing 3306 from sg-021b44b3b4972c25b and 76.131.37.73/32. Database performance_schema.hosts identifies that address as the only recorded external client; it matches the operator computer's current public IP. Preserve the shared mysql security group on its other consumers. Enable deletion protection; keep public access for the operator.
4. Verify new Sterling database connections. Recheck allocations, change only MANAGED_DATA_RDS_ADMIN_CONNECTION_PROD in workspace-managed-data-credentials, and restart only the six Workspace deployments. Preserve all other Secret values and deployment configuration.
5. Test live allocation, app records/files/cache writes and reads, restart retention, ordinary teardown/republication retention, and permanent deletion using a private disposable project in groundx-studio-dev. Verify Sterling remains connected and app data stays isolated.
6. Remove only this rollout's disposable resources and obsolete core managed administrator after validation and zero old allocations. Archive the completed record on the existing operations branch.

The managed administrator needs global CREATE USER because the existing provider creates and drops app users; MySQL cannot restrict that privilege by user-name prefix. Database grants remain limited to managed production schemas. No runner or scaffold code changes are needed. Extraction, Arcadia legacy/v1, generic v1, and ADP v1 are unaffected because their settings and workloads do not change.

## Local work registration

Owner: AGE-344 operations.
State: accepted.
Disposition: Live switch, isolation, retention, and permanent deletion verified. Sanitized results handed off to rollout.md; temporary helpers and snapshots approved for removal.
Reason: bounded live switch verification and cleanup helpers.
Expiry: 2026-09-16T23:59:59Z.
Exact run root: /Users/benjaminfletcher/git/groundx-on-prem/.worktrees/age-344-purge-rollout/openspec/work/switch-managed-records-to-studio/live.
Summary root: openspec/runs/switch-managed-records-to-studio.
Durable handoff: rollout.md beside this design. No raw logs or credentials belong in the tracked record or retained summary. Settle the run and remove its exact root before archive; retain the lifecycle summary for 90 days.
