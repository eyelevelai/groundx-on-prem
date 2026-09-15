# Studio managed-records switch

Account 903713046261, us-west-2, EKS eyelevel_890ng3. Helm groundx revision 380 remains unchanged. No application source, image, chart, database engine, instance count, or capacity range changed.

## Database and access

New managed production records use groundx-studio.cluster-cgy1fmuybzi6.us-west-2.rds.amazonaws.com:3306. Core GroundX data and Workspace metadata remain on their existing database. Development managed records remain on dev-v3. Production objects and cache remain unchanged.

Before switching, the Workspace allocation table contained no allocations. The only older queued operations were two deployment diagnostics from August 31, not allocations. Studio contained only system schemas and sterling-extract. Sterling development's live private client matched its Kubernetes pod. The only external address recorded in performance_schema.hosts was 76.131.37.73, matching the operator computer's current public IP. Public network probes in VPC flow logs were not treated as authenticated clients.

Dedicated security group sg-0b644d4e008f061b3, groundx-studio-db, now exclusively protects the cluster. It permits TCP 3306 from EKS worker group sg-021b44b3b4972c25b and operator address 76.131.37.73/32 only. The old broadly accessible group sg-0177b3b6116fd4c02 remains unchanged on its other consumers. The database ENI confirms the dedicated group is attached. Public accessibility remains enabled for the verified operator path, but unrestricted IPv4/IPv6 database ingress is removed. Deletion protection is enabled. Seven-day backups, encryption, the single serverless writer, and its 0.5 to 16 ACU range remain unchanged.

Studio administrator gx_managed_prod_admin requires TLS, can create users, and delegates database privileges only for gx-%-prod schemas. MySQL user-lifecycle privileges are necessarily global with the existing provider. Existing Sterling credentials were neither changed nor rotated. Actual AwsManagedDataProvider allocation succeeded before the switch and again after network restriction. A temporary app identity wrote and reread data through separate verified-TLS connections, was denied mysql.user access, and was deleted with its schema. Sterling opened fresh verified-TLS connections and the operator received a MySQL handshake after the restriction.

Only MANAGED_DATA_RDS_ADMIN_CONNECTION_PROD changed in the Workspace-specific Secret. Every other value and key was compared and preserved. All six Workspace deployments restarted and reached one ready, available replica at their unchanged image digest, sha256:17e8e3e7abce8972b95886e190beb48239df9c26659b5eb7b7601e50766aaf02. Each process independently confirmed the Studio production endpoint, verified development and production database TLS connections, and retained the production S3 and Redis settings.

No new database capacity or cache was purchased. Added application workload may increase usage charges on the existing Aurora cluster.

## Disposable app verification

Project age344-studio-check-20260914, named AGE344 Studio storage check 20260914, uses caller mode with no GroundX runtime credentials, no AI calls, and private services in groundx-studio-dev.
Repository: GroundX-Studio/workspace-age344-studio-check-20260914-281b597d.
Scaffold main: b26a0eb4c6404e846ab3fc7702b9d24a63bf60ab.
Managed branch: 1a84e4f9fe90d07f3cab63e518e4e1e9f79a8807.
Create operation: operation-150c0a0d-6000-4794-bc68-442d29b6885f.
Production records, objects, and cache allocation: operation-39b2fd9f-33ab-4647-bc8c-9a3a46ee2ab6, succeeded.
Publish operation: operation-38ea5f6c-6c8f-4353-a5ca-d84cb407f19f.
Production deploy run 34895578321 succeeded. The deployed MySqlAppRepository and managed object/cache adapters wrote and reread all three test values. App access to mysql.user, an S3 key outside its prefix, and a Redis key outside its hash tag was denied. Frontend-proxied /api/healthz returned HTTP 200 with all three capabilities ready, the expected commit and environment, and no GroundX runtime credentials. Services are private ClusterIP services and no Ingress exists.

All three values survived a middleware restart. Runtime Secret UID and content digest remained unchanged. Sterling's middleware /api/healthz also returned HTTP 200 and status ok.

Ordinary teardown operation operation-941b0cc1-cf74-477e-81e5-d08c9cfbb480 and uninstall run 34895927568 succeeded. App deployments, pods, services, and ingress resources were absent afterward; the runtime Secret retained its original UID and exact content digest. Republication operation operation-a27b78b3-6862-4bee-9f37-ef67b19134f1 and deploy run 34896060747 succeeded at the same commit. The republished app read all three original values, retained its runtime Secret UID and content digest, and returned matching ready health through the frontend.

Permanent cleanup operation operation-6acfa3fb-e423-4691-8abb-cbb9dc6cb6ff succeeded at 2026-09-14T21:08:33Z. It confirmed uninstall runs 34896956435 (dev) and 34896990364 (prod), deleted all three production allocations, removed runtime resources and credentials, deleted the GitHub repository and runner checkout, and removed project metadata. Independent reads confirmed no project, instance, intent, allocation, purge marker, app database or SQL user, S3 objects or IAM user, or Redis user. The runtime Secret and application workloads are absent. The cache group is active with only its disabled default user. GitHub returns 404 for the deleted repository while the same credentials can read the private scaffold.

Both exact test image tags and the two superseded, untagged image manifests from the initial deploy were deleted from ECR Public. Shared image repositories and unrelated images were preserved.

After zero allocations, zero old managed schemas, and zero old administrator connections were verified, the unused gx_managed_prod_admin account was dropped from groundx-production-cluster. The temporary rollback Secret workspace-managed-data-studio-staging was deleted. Studio's administrator remains in the Workspace-specific Secret. Existing app and master credentials were not rotated.

Final reads confirmed the old administrator is absent, Studio's administrator requires TLS, no test managed schemas or allocations remain, and Sterling still opens a fresh TLS connection. All six Workspace deployments remain ready; groundx-studio is available with deletion protection and its dedicated group. OpenSpec strict validation passed. No chart or application source changed, so Helm and application unit suites were not rerun for this operational record.

## Local closeout

Owner: AGE-344 operations, groundx-on-prem. The sanitized rollout record is the durable handoff. Temporary work root: /Users/benjaminfletcher/git/groundx-on-prem/.worktrees/age-344-purge-rollout/openspec/work/switch-managed-records-to-studio/live. Its inventory contains 6 files, 20,275 bytes. The bounded lifecycle summary is openspec/runs/switch-managed-records-to-studio/summary.json, retained through 2026-12-13. The adjacent closeout receipt records verified removal and summary digest. No other local work root is part of this change; the existing operations worktree and unrelated runner test report are preserved.
