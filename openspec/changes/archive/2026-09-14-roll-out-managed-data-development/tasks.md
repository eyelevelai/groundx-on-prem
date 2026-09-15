## Development rollout

- [x] Verify account, production boundaries, merged source, and current deployment.
- [x] Build and verify immutable Workspace image from 8e5d732841ef3eb72fbe84099b92699b7c2aa262.
- [x] Verify development database administration and safe connectivity.
- [x] Verify the development database accepts TLS with certificate and hostname validation.
- [x] Add opt-in CA-file settings for runner metadata and managed MySQL connections, retaining driver defaults when unconfigured.
- [x] Carry managed database certificate verification into the existing application DATABASE_URL binding.
- [x] Test missing/untrusted certificates, hostname mismatch, encryption refusal, and existing connection behavior.
- [x] Create isolated namespace with bounded resource use and no public load balancers.
- [x] Verify scoped rollout against the deployed chart release line and preserve rollback state.
- [x] Configure a dedicated runner identity without changing shared network policies.
- [x] Provision development-only S3 and encrypted Redis access controls.
- [x] Update existing Workspace API and workers, retaining their metadata database and broker.
- [x] Deploy the matching facade changes to the existing API entrypoints.
- [x] Verify allocation, app-path reads and writes, project isolation, and persistence.
- [x] Verify republish and teardown preservation.
- [x] Verify confirmed synthetic-project deletion and remove the residual runtime Secret.
- [x] Record deployed refs, resource ownership, costs, rollback, and remaining work.

## Earlier isolated-runner checks

Production was read, not modified. Workspace image build:
https://github.com/EyeLevel-ai/groundx-workspace-runner/actions/runs/34735944660

Created namespace `groundx-studio-dev`, resource quota `development-budget`, and
limit range `development-defaults`. Added public CA ConfigMap `workspace-db-ca`
on 2026-09-13 after server-side dry-run validation. No running services, cache, database allocations, file
buckets, app identities, or development API changes have been provisioned.

Image: `public.ecr.aws/c9r4x6y5/eyelevel/workspace-runner@sha256:a461212b8f152846d16e56525241f91a40b5abc5d3d41db50a2e9cd447b4014c`.
Both amd64 and arm64 build jobs and the multi-architecture manifest job passed.

Database gate: existing development credentials can connect to `dev-v3` in
us-east-1 with TLS and have schema/user administration grants. The development
Workspace namespace is in us-west-2. No inter-VPC peering was found. The merged
runner's metadata connection and managed-data administration connection do not
pass TLS settings; managed-data administration also ignores URL TLS options.
Do not deploy those connections across the public endpoints until verified TLS
support is implemented and tested. No credentials were written to local files.

On 2026-09-13, a read-only PyMySQL connection to the exact `dev-v3` endpoint
passed certificate-chain and hostname verification using the AWS RDS trust
bundle. `SELECT 1` passed and the session reported TLS_AES_256_GCM_SHA384.
No database writes occurred. PyMySQL 1.2 requires TLS when explicitly configured;
the runner dependency floor must include that refusal behavior rather than allow
an older driver to fall back when a server does not advertise TLS.

Runner PR https://github.com/EyeLevel-ai/groundx-workspace-runner/pull/11,
commit `d952718553e4161a1895b5abdbf6e3f1ebdd0619`, adds the CA-file settings and verified application URL.
All 410 tests passed with 100% coverage; type, security, and secret scans passed.
Both changed production connection methods and the unchanged scaffold
`MySqlAppRepository` at `b304ee864ad44861c2629f56f1624d0fff406d21` completed
read-only queries with verified TLS. The regional CA produces a 5170-byte URL,
below GitHub's 48 KB secret limit. No production workloads changed.

Remaining prerequisite checks: no Workspace/GitHub-named development credentials
were found in Secrets Manager or Parameter Store in either region, and the
development namespace has no credentials. GitHub authentication still needs an
explicit development identity. The shared aws-eks-nodeagent currently has
`--enable-network-policy=false`; namespace separation is not network isolation.
Do not change shared cluster networking or reuse production credentials under
this development-only rollout.
The GitHub organization-installations read returned insufficient access
(`admin:org` required); no permissions were expanded.

Both push and PR CI runs passed for `d952718553e4161a1895b5abdbf6e3f1ebdd0619`,
including Python 3.11/3.12, security scans, Docker builds, and Compose lifecycle
integration. PR 11 has no merge conflicts and requires review.
Build https://github.com/EyeLevel-ai/groundx-workspace-runner/actions/runs/34753529184
produced multi-architecture image
`public.ecr.aws/c9r4x6y5/eyelevel/workspace-runner@sha256:e3169e4caf98de8693ef30cd6ad6fc730971185bc42288e73208cd5bb865cb55`.

Job `check-database-tls-d952718` used that image in `groundx-studio-dev` and
verified certificate trust, hostname, and encrypted reachability for both runner
connection methods. Intentionally invalid synthetic credentials were rejected
after TLS; the job issued no queries and contained no real credentials. The
completed job was removed. This does not establish app readiness or replace the
remaining allocation, persistence, and lifecycle tests.

## Existing-service rollout, 2026-09-13

The rollout now reuses the existing six Workspace deployments in `eyelevel`,
their GitHub App, broker, metadata database, and PVC. The existing installation
was verified through the runner's GitHub client. No second GitHub identity is
needed. The earlier restriction on reusing that connection no longer applies.

The production Helm release is `groundx`, revision 367, chart 0.2.7. Repacking
its exact embedded chart reproduces its manifest without workload differences.
Overlay only the Workspace managed-data templates and schema/defaults; retain
all unrelated live chart content and values.

Database allocation test passed using `AwsManagedDataProvider` at `d952718` and
the scaffold's `MySqlAppRepository` at `b304ee8`: verified TLS, schema creation,
read/write, reconnect persistence, cross-project rejection, and deletion.
Both disposable schemas and users were confirmed absent afterward. This is not
published-app or restart/republish evidence.

Created IAM role `eyelevel-workspace-managed-data`, its development-only inline
policy, and ServiceAccount `eyelevel/workspace-runner`. Policy validation and
readback passed. No running deployments use the identity yet.

Created private, encrypted, unversioned S3 bucket
`groundx-studio-managed-data-dev-903713046261`, with public access blocked and
unencrypted transport denied. Created cache security group `sg-072b36b7799cda6f1`
allowing port 6379 only from existing worker group `sg-021b44b3b4972c25b`, plus
disabled default Redis user `gx-managed-data-default-dev`.

The API rollout branch `ops/age-344-live-api` starts at deployed source `cd8e2ba`
and includes only merged AGE-344 commit `35ae64d`, producing `dbbf2d4`.
Both changed packages pass `go test -short ./pkg/partner ./pkg/mcp -count=1`.
The first image build lacked its same-tag Golang base image. The base build
passed; the dependent API build is pending. No live service images or settings
have changed yet.

Redis cache `gx-managed-data-dev` is creating with one `cache.t4g.micro`, Redis
7.1, cluster mode, zero replicas, required TLS and at-rest encryption, private
subnets, and user group `gx-managed-data-dev`. Cluster mode requires the
automatic-failover flag even with zero replicas; this is not redundant capacity
or an availability guarantee. Node cost is $0.016/hour, about $11.68 per 730-hour
month, excluding traffic and S3 usage. No existing cache was changed.

## Rollout attempt, 2026-09-14

Verified pushed refs: runner `d952718`, deployment configuration `ec2eae5`,
and API `dbbf2d4`. The API package tests and container build passed. The
development cache is available and requires TLS. The bucket blocks public access.

Helm revision 368 changed only the six Workspace images and service accounts,
with managed allocation disabled. The new API failed before startup because
the injected monitoring package supplies typing_extensions 4.15.0, which lacks
the lowercase `sentinel` imported by the image's AnyIO. The existing API remained
available. The upgrade was canceled and atomically rolled back to revision 367
as revision 369. All six deployments returned to their previous images and the
API health and project-list routes returned HTTP 200. The GroundX API was not
updated, and no managed test app was created.

Before another rollout, reproduce API startup with the monitoring dependency
combination, constrain compatible runner dependencies, and test the resulting
image with the actual cluster injection enabled. Existing `/storage` timed out
before the rollout; that is not evidence of a new regression.

Runner commit `404b2a1c9df9772e59e5bf6a8e4be365183f5642` constrains AnyIO to
4.14.1, compatible with the injected typing_extensions 4.15.0. The startup
regression test reproduced the import failure with 4.14.2 and passed with the
constraint. All 411 tests passed with 100% coverage in a fresh dependency
environment using typing_extensions 4.15.0; type, dependency vulnerability,
Bandit, and secret checks passed. Push/PR CI, including Compose lifecycle
integration, passed. Build run `34869284636` produced multi-architecture digest
`sha256:ecbcc17346c738cd9bc55ecc42c5299b665ff90c488ae1e89c2d445dba2384ee`.

Job `check-runner-startup-404b2a1` used that build's amd64 image in `eyelevel`
with all four live monitoring injectors. It verified the loaded Python
monitoring path, AnyIO 4.14.1, actual API startup, and HTTP 200 from `/health`.
The job had no credentials or service account token and was removed after
successful completion. The full Helm production gate also passed.

Helm revision 370 deployed the verified runner digest and dedicated identity to
all six existing Workspace deployments with allocation disabled. Server-side
preview verified no other resource changes, including monitoring certificates.
The new API returned HTTP 200 for health and project listing. Its runtime role
is `eyelevel-workspace-managed-data`; all three additive managed-data metadata
tables exist. Existing metadata database and broker settings are unchanged.

Helm revision 371 deployed only the matching GroundX API image at `dbbf2d4`.
The standard production Lambda release deployed the same source with unchanged
configuration. Lambda code hash is `QlGkoqVlz7fgFVafGFxmjdeDTrN3J+i0sGxF3XtnSbM=`;
version 3 retains the previous package for rollback. Lambda reports Active and
Successful. Project creation through the updated facade succeeded.

Revision 372 enabled development allocation and mounted the public CA.
`workspace-managed-data-credentials` contains only the development database
administration credential. The existing shared credential Secret remains
unchanged. Server-side preview limited changes to Workspace configuration and
the seven Workspace/API deployments. The running runner passed a verified-TLS
database query and reported all production provider settings empty.

Disposable project `892ba7db-542f-4da6-bdd1-6acaa10b2f18`, named
`AGE-344 storage check 20260914`, was created and cloned to
`/Users/benjaminfletcher/git/age344-storage-check-20260914`. Its unchanged
scaffold passed 266 frontend and 140 middleware tests, build, and secret scan.
App setup uses caller mode with no Studio runtime key; no AI requests are part
of this test. Permanent deletion requires exact-name confirmation.

Initial deploy configuration failed while allocating cache, before records or
objects. CloudTrail confirmed CreateUser succeeded but ModifyUserGroup was
denied for `user:gx-373cdb9b5bcf-dev`. The dedicated role requires that action
on both the development group and the development user ARN. Add only the
`gx-*-dev` user ARN to that existing statement; production users and other
groups remain denied. No shared role policy changes are needed.

The policy change at `39245c9` passed AWS policy validation and before/after
simulation, including denied production-user and unrelated-group cases. It was
applied only to `eyelevel-workspace-managed-data` and read back successfully.
Deploy-config operation `operation-70fbcf0d-067b-4189-945f-e2487c0bab73`
succeeded; all three allocations are ready. Cache group propagation took about
two minutes, within the existing timeout.

Development publish run `34871677681` succeeded for app commit `fe3be95`.
The frontend-proxied `/api/healthz` returned the exact commit, caller mode,
development environment, and all three managed capabilities ready, with no
GroundX runtime keys configured. Both services are private ClusterIP services.
`check-app-data.mjs` used the deployed application repository and adapters to
write and read synthetic values. Database access outside the app database,
S3 writes outside its prefix, and Redis writes outside its prefix were denied.

The scaffold does not implement the optional `restartDeployments` workflow
action, so the operator restarted only the disposable middleware deployment.
Pod UID changed from `9b71effd-8e39-4752-b116-b9dae157058f` to
`76bf6a7b-1f34-4859-943e-b49fb61740ae`; the new pod read all three original
values successfully. Uninstall run `34872239946` then succeeded through the
normal deployment-teardown route, leaving no app deployments, pods, or services
in the development namespace.

Republication run `34872464618` succeeded at the same `fe3be95` commit. The
new middleware pod UID `3a5686e2-d004-4a4f-b74e-abf2fc1784cb` read all three
original values without rewriting them. Frontend-proxied health returned the
same commit and all capabilities ready. Services remain private. The cache
value has a one-hour TTL; persistent storage does not depend on cache retention.

Runner PR 11 merged on
2026-09-14 as `01f5a3f3df06cae3d2bdd75241c5db4bddf77ce8`. Its merged tree
matches the deployed source at `404b2a1`; no deployment change is required.
The merged feature branch and local worktree were removed. Deployment-source
branches and their records remain available for rollback.

## Deletion and closeout, 2026-09-14

Confirmed permanent-deletion operation
`operation-5e3e0ee1-ce4c-4558-a4e3-80d01c2fd039` succeeded. It deleted all three
development allocations, the managed repository, project metadata, and runner
workspace cache. Uninstall runs `34877898791` (dev) and `34877990747` (prod)
confirmed deployment removal. The production target contained no application
workload; no customer project was affected.

Independent reads found zero app databases, database users, project rows,
managed-data intents, allocations, or purge rows. The S3 prefix is empty, the
app IAM and Redis users no longer exist, and the Redis group contains only its
disabled default user. GitHub returns HTTP 404 for the deleted repository.

The workflow left one middleware Secret in `groundx-studio-dev`. The deploy
workflow creates that Secret outside Helm; uninstall intentionally excludes
Secrets, and permanent purge uses the same uninstall workflow. The operator
deleted the exact unused app Secret after all app workloads were gone.
A final cluster-wide name check found no app deployments, pods, services, or
Secrets. Automatic purge therefore did not complete credential-copy cleanup
without operator intervention.

Before production rollout, permanent purge should remove the verified app-owned
middleware Secret while ordinary teardown continues to preserve it. Do not delete
shared namespaces, TLS Secrets, registry credentials, or user-owned shared Secrets.
This follow-up affects the scaffold uninstall contract and the runner purge caller;
it is not required to finish deleting this disposable project.

Removed four exact test-app ECR tags and the unused development TLS-probe
ConfigMap. Moved the local test checkout to the user's Trash. The private data
services, namespace quota, and dedicated runner role remain for development use;
cache cost remains about USD 11.68 per 730-hour month, plus storage and traffic.
Production managed-provider settings remain empty. Shared customer data and
existing application bindings remain unchanged.
