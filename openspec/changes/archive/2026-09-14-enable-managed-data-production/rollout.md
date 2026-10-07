# Production managed storage

Account 903713046261, region us-west-2, EKS eyelevel_890ng3.
Baseline Helm release: groundx, namespace eyelevel, revision 379.

## Database

Production records use the existing private, encrypted Aurora MySQL cluster
groundx-production-cluster, with its current writer endpoint. New administrator
gx_managed_prod_admin requires TLS, has database privileges only for managed
production schemas, and has the CREATE USER privilege required by the allocator.
That MySQL user-lifecycle privilege is global, not constrained by a user-name prefix.
The connection is stored only in workspace-managed-data-credentials. Every
pre-existing credential value remained unchanged.

Before provisioning paid resources, AwsManagedDataProvider created a disposable
production schema and app user. Writes persisted across connections. The app
could not read mysql.user; the dedicated administrator could not see the eyelevel
schema. Provider deletion removed the temporary schema and user. The generated
application URL was 10,228 bytes, below GitHub's 48 KB secret limit.

The public CA bundle in workspace-managed-db-ca-regions covers us-east-1 and
us-west-2 so development and production retain verified TLS connections.

## Objects and cache

Production bucket: groundx-studio-managed-data-prod-903713046261. Public access
is blocked, ACLs are disabled, server-side encryption is enabled, and the bucket
policy rejects non-TLS access.

Production cache: gx-managed-data-prod, Redis 7.1, two cache.t4g.micro nodes,
one shard, automatic failover, multi-AZ, encryption at rest, and required TLS.
The default Redis user is disabled. Dedicated security group sg-0664ec90101173738
accepts port 6379 only from the existing worker security group.

The dedicated Workspace IAM policy retains development object storage and adds
production object identities and storage permissions. Cache permissions now
target production identities and its user group only. Access Analyzer returned
no findings; simulation allowed production cache identity creation and denied
development and unrelated cache identities.

The gx-managed-data-dev cache, user group, disabled default user, and dedicated
security group sg-072b36b7799cda6f1 were deleted after verifying zero managed
allocations and no app users. Development records and objects remain. The shared
cache subnet group was preserved.

Production cache became available with its two nodes in us-west-2b and us-west-2d.
The server-side Helm preview changes only the Workspace configuration Secret and
six Workspace deployments. Revision 379 already omits extraction reasoningEffort;
the previous rollout's explicit null override is unnecessary and must not be
carried forward. Omitting it preserves every unrelated rendered resource.

At the verified price of $0.016 per node-hour, production cache costs $23.36 per
730-hour month. Removing the $11.68 development cache makes the net increase
$11.68 per month, excluding usage-based storage, database, and transfer charges.
No reservation or commitment was purchased.

## Disposable verification

Private project age344-prod-check-20260914 uses caller mode, no AI calls, and
the existing groundx-studio-dev namespace with production storage identities.
Repository: GroundX-Studio/workspace-age344-prod-check-20260914-8222351e.
Scaffold main: b26a0eb4c6404e846ab3fc7702b9d24a63bf60ab.
Managed branch: c6cbde518edc57e8b17704f4a00de7f085ce7245.
Create operation: operation-e9f69733-f2bd-4f46-b55b-969b6edc4dee.
Helm revision 380 deployed successfully. All six Workspace deployments have
one updated, available replica at the unchanged runner image digest
sha256:17e8e3e7abce8972b95886e190beb48239df9c26659b5eb7b7601e50766aaf02.
Production provider settings are loaded; development cache settings are empty.
Actual provider connections verify TLS for both development and production
databases after the update.

Managed allocation operation operation-c4a0e273-b51b-4aca-a4f8-8008ead60423
succeeded for records, objects, and cache. Production publish run 34891833568
succeeded. Frontend-proxied health returned HTTP 200, the expected commit and
production environment, all three capabilities ready, caller mode, and no
GroundX application credentials. Both services are private ClusterIP services;
there is no Ingress.

The deployed application's MySqlAppRepository and managed S3/Redis adapters
passed actual writes and reads. Database access to mysql.user, S3 writes outside
the assigned prefix, and Redis writes outside the assigned hash tag were denied.
All three persisted values survived a middleware restart, with runtime credential
identity and bytes unchanged. Ordinary uninstall run 34892335405 succeeded,
removing app deployments, pods, services, and ingress resources while preserving
the runtime Secret's identity and bytes. Republication run 34892466073 succeeded
at the same source commit. Frontend health and actual reads confirmed all three
stored values remained, with the runtime Secret's identity and bytes unchanged.
Permanent deletion operation operation-3af08c59-9d19-4ccb-9e06-52c19687c4c6
succeeded at 20:31:39 UTC on 2026-09-14. Uninstall runs 34893310783 (dev) and
34893352068 (prod) succeeded. The runner removed all three production allocations,
the deployments, runtime credentials, repository, project, and runner checkout.

Independent reads confirmed no project, instance, intent, allocation, or purge
marker. Only the successful cleanup receipt remains. The app database and database
user are absent; its S3 prefix is empty; its IAM and Redis users are absent. No
test deployment, pod, service, ingress, or Secret remains in any namespace.
GitHub returns 404 for the deleted repository while the same credentials can
read the private scaffold repository. Both exact test image tags were removed
from ECR Public; shared image repositories and unrelated tags were preserved.

Production storage is enabled and verified. Development cache removal is complete.
Existing customer apps, development records/files, and pre-existing credentials
were not changed. No existing credential was rotated.
