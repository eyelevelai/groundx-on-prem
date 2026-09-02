# Design

Add one `workspace.managedData` block. The chart writes only the enable flag, AWS region, S3 bucket names, Redis endpoints, and Redis user-group IDs into `config.py`. RDS administrator URLs stay out of values and come from `workspace.existingSecret` as `MANAGED_DATA_RDS_ADMIN_CONNECTION_DEV` and `MANAGED_DATA_RDS_ADMIN_CONNECTION_PROD`.

The Workspace service account supplies the runner's AWS control-plane identity. The runner creates app-scoped credentials and injects them into each app's existing GitHub environment secret boundary. No new Kubernetes workload or provider abstraction is added.

Rollout dev first with a pre-created secret and least-privilege service-account role. Verify allocation, republish, isolation, and confirmed deletion, then enable prod. Disabling the flag stops new reconciliation but preserves existing data. This chart change performs no stateful migration and causes only Workspace pods to roll.
