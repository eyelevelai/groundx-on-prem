## Deployment

Use the current deployed chart and runner image. Review the server-side manifest
diff before applying. Only Workspace provider configuration, the Workspace-only
secret binding, and affected Workspace pod configurations may change. Serialize
the shared Helm release with other deployments.

Create production resources separately from development: private S3 bucket,
TLS-required encrypted Redis 7.1 cache, production user group, disabled default
cache user, and per-project production identities. Scope the runner role to the
production bucket/prefix and production app identities without expanding unrelated
permissions. Use the current allocator and facade, not direct replacement paths.

The production database is groundx-production-cluster in us-west-2. The stored
groundx_studio connection reaches it but cannot create users or delegate grants.
The saved administrator credential in prod-RDS-datascience2023-w authenticates
against the current writer and can create users and delegate privileges. Its
stored hostname names the former cluster; never use that hostname as the target.
Both live preflight queries used verified TLS. No data or credentials were changed.

Use a dedicated new administration account restricted to managed production
schemas and necessary user lifecycle operations. Store its connection only in
the Workspace-specific Secret. Preserve every existing credential. Extend CA
trust to cover both existing east-region development and west-region production
endpoints; verify both paths and the generated app URL size before rollout.

## Verification and rollback

First test production database allocation through the production provider and
application repository, including verified TLS and denied cross-app access.
Provision paid resources only after setup and cost approval. Verify IAM scope,
private networking, bucket access controls, and cache encryption before enabling.

Use a disposable private caller-mode app with synthetic data and no AI calls.
Verify actual record, file, and cache writes/reads, cross-project rejection,
restart and republication persistence, ordinary teardown preservation, and
confirmed permanent deletion of owned data, credentials, deployment, repository,
and metadata. Do not migrate or reconfigure existing customer apps.

Restore prior production provider settings if activation fails. Preserve
development settings and any durable allocations. Remove only verified disposable
test resources. Remove the unused development cache, its user group, disabled
default user, and dedicated cache security group after verifying no app allocation
depends on them. Clear development cache provider settings and remove only its
cache-specific IAM permissions. Preserve development records and objects.

## Local run

Owner: AGE-344 operator. State: accepted. Reason: production rollout and disposable
test, including confidential temporary connection material. Exact root:
`/Users/benjaminfletcher/git/groundx-on-prem/.worktrees/age-344-purge-rollout/openspec/work/enable-managed-data-production/live`.
Disposition: production storage and lifecycle checks passed; development cache and
disposable cloud resources removed. Reviewed evidence is retained in rollout.md,
owned by the AGE-344 operator. Close the temporary root before archive; retain only
the bounded lifecycle summary through 2026-12-13 and its tracked closeout receipt.
