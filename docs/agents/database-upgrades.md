# Database migration gate

Upgrades with any Go API or ingestion workload run a database migration Job
before Helm updates normal release resources. This includes worker-only
deployments with `groundx.enabled: false`. The Job uses the image selected by
`groundx.image`, or the normal GroundX image default, with `-migrate-only`.
Use a Cashbot image containing that command and the matching worker schema
checks. Merge/build the Cashbot companion before deploying this chart.

No new config.yaml setting, service or migration image is required. The Job
uses the target release's normal configuration in a separate release-scoped
Secret, never overwriting `config-yaml-map` while old pods are running. It
inherits GroundX image-pull, security, resource, service-account and scheduling
settings and global `cluster.secrets` environment imports. It does not wait
for Redis, search, storage, workspace or queue services.

Database endpoints, credentials, service accounts and image-pull Secrets used
by the hook must already be usable before the upgrade. Provision new external
dependencies separately; a pre-upgrade Job cannot use resources first created
by the regular release phase. Do not combine a database endpoint move with
application rollout without preparing and verifying the target database first.

## First install and upgrade

Fresh installs have no pre-install migration hook. GroundX initializes its
database after backing services become available. Compatible Go workers check
their reader and writer schema before consuming messages. Worker-only fresh
installs require a database prepared by the GroundX migration command.

For upgrades, review the target Cashbot release's database requirements and
test against the actual database engine/version before applying. Routing
columns use instant addition; the returned-extraction index uses online index
creation and consumes database I/O. Migrations need authorized DDL privileges
and may fail on metadata locks or an unsupported table configuration.

The Job has a 15-minute deadline and no automatic retry. Allow enough Helm
timeout for both the migration and the remaining rollout, for example:

```sh
helm upgrade groundx ./src/groundx -n eyelevel -f values.yaml --timeout 20m
```

Use the actual release, namespace and approved values. Do not use `--no-hooks`:
it bypasses the pre-rollout ordering protection. Runtime startup checks still
reject incompatible schema, but they cannot preserve the old rollout by
themselves. A chart render proves configuration, not database migration or
successful ingestion.

## Failure and rollback

A failed migration hook stops the upgrade before normal resources are updated.
The Job and its configuration Secret remain for diagnosis. The name is the
release name truncated to 46 characters, with `-schema-migration` appended.
Inspect the Job's pod logs and database error; do not print its Secret. Fix the
underlying cause and retry the upgrade. A retry replaces previous hook resources;
save relevant logs first. Successful hooks are removed automatically.

Already applied SQL is not rolled back when the Job fails. The runner resumes
partial additive upgrades. Application rollback retains added columns, indexes
and document receipts. Helm does not restore external database state. Retain
pending-document recovery dependencies when choosing the previous image.
