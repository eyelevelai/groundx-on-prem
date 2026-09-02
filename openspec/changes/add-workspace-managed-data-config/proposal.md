# Add Workspace managed-data configuration

The Workspace runner already accepts managed-data configuration, but the Helm chart cannot supply it. When managed data is enabled, every Workspace API and worker pod must receive the same non-secret AWS resource settings and the existing Workspace secret must supply the two RDS administrator URLs.

This changes only Workspace pods. It does not create, modify, or delete RDS, S3, Redis, IAM, Kubernetes, or cloud resources. Existing installs remain disabled by default. Rollback disables the setting and restores the prior runner image without deleting allocations.

Affected environments: any dev or prod cluster that explicitly enables the setting. Open questions: none.
