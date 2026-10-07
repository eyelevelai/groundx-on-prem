## Why

AGE-344 is merged, but the deployed Workspace service and APIs predate it.
Deploy through the existing live services and verify with disposable projects
using development-only app storage.

## What Changes

- Update the six Workspace deployments in `eyelevel` and their GroundX API
  callers. Keep the existing GitHub connection, metadata database, queues,
  and workspace volume. Add the three managed-data metadata tables.
- Use existing development RDS capacity, a private S3 bucket, and one encrypted
  Redis cache with app-scoped access. Give the runner a dedicated AWS role
  without expanding the shared worker role.
- Bound the cache to one `cache.t4g.micro`, previously estimated at USD 12/month,
  excluding transfer and file-storage usage. Verify price before creation.
- Do not add another runner, GitHub App, public load balancer, or cluster.
- Verify allocation, application reads and writes, isolation, restart,
  republish, teardown preservation, and confirmed test-project deletion.

## Scope and rollback

AWS account: 903713046261. Cluster: `eyelevel_890ng3`, us-west-2.
Existing customer app deployments and storage bindings remain unchanged.
Only disposable projects receive managed-data intent; production provider
settings remain empty. Shared IAM policies and networking remain unchanged.

Record image digests, Lambda versions, Helm revision, and configuration before
mutation. Reject renders that change unrelated workloads. On failed verification,
restore prior service versions and configuration without reverting concurrent
unrelated changes. Retain additive metadata tables and durable allocations.
Delete only verified disposable test resources. Do not create paid resources
while missing prerequisites prevent testing.

Open design questions: none.
