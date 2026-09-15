## Scope

Reuse the existing Workspace service in `eyelevel`, including its GitHub
connection, queues, metadata database, and workspace volume. Update its API
callers as needed. Existing customer app deployments and data bindings remain
unchanged. Only disposable test projects use development managed storage.

## Database connection gate

Verify trusted certificates and hostname matching before allocating data on the
development RDS instance. Mount the regional public CA bundle and configure the
runner's managed administration CA setting. New application DATABASE_URL values
carry the public CA and verification flags through the existing secret binding.
Keep the secret under GitHub's 48 KB limit. Missing or invalid certificates must
fail before authentication, without unencrypted fallback. Do not rebind existing
app allocations. Preserve the existing metadata connection unless its exact
endpoint has separately passed verification.

## Rollout order

1. Verify pushed refs, tests, current deployments, and rollback state. Use the
   deployed chart release line and port only managed-data configuration.
2. Verify database TLS, existing GitHub access, dedicated runtime permissions,
   and network reachability before creating paid resources.
3. Create development-only S3 and one encrypted cache. Leave production managed
   provider configuration empty.
4. Deploy the runner with allocation disabled first, then matching API changes.
   Verify existing read-only paths before enabling development allocation.
5. Test allocation, app-path writes and reads, project isolation, restart,
   republish, teardown preservation, and confirmed disposable-project deletion.

## Rollback

Restore recorded images and settings immediately if verification fails. Do not
revert unrelated concurrent deployments. Keep additive metadata tables and durable
allocations. Remove only disposable resources with verified ownership.

## Isolation boundary

Database roles, S3 permissions, and Redis ACLs separate app data by project and
environment. This is not network isolation. Shared cluster network-policy
enforcement is unchanged. No GitHub credentials move to a second runner.

Use a separate Secret through `workspace.existingSecret` for development database
administration. The chart keeps the existing shared credential Secret attached;
the additional Workspace Secret contains only the development database credential.
Do not add the database credential to `eyelevel-secret-credentials`, which also
feeds unrelated extraction, search, and metrics services.
