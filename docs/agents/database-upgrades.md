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

Cashbot releases containing the account process lookup index require
`training_username_status_started_idx (username, status, started_time)` on
`nlp_model_training`. Cashbot owns both fresh table creation and the shared
upgrade SQL. Select a GroundX image containing that migration before upgrading;
the existing `-migrate-only` hook adds the index with
`ALGORITHM=INPLACE, LOCK=NONE`. No separate chart SQL, configuration field or
hook is needed. Fresh API installs initialize it normally; worker-only fresh
installs still require a prepared database. Updated APIs and Go workers check
the index on reader and writer endpoints before accepting work.

Building the index consumes database I/O and storage, and process writes maintain
it afterward. Validate construction time, query-plan selection and status-list
latency on the actual target engine. Keep the index when rolling application
images back. An incompatible existing index or unsupported online operation
stops migration without a blocking fallback.

The Job's time limit and retry count are chart values:

- `groundx.migration.activeDeadlineSeconds` (default `3600`) is the time limit
  for the whole Job, in seconds.
- `groundx.migration.backoffLimit` (default `2`) is how many times Kubernetes
  starts a new pod after a failed one.

Retries share the deadline. Each attempt waits up to 30 seconds for the GroundX
migration lock and fails if another process still holds it. When the deadline
passes, Kubernetes stops the Job even if retries remain.

Time `-migrate-only` on a restored snapshot of the database before the upgrade.
Set `activeDeadlineSeconds` above the measured time. Row count is context only:
use the measured time, not an estimate from the number of rows.

Set `--timeout` above the Job deadline plus the time the rollout needs. With the
default deadline, for example:

```sh
helm upgrade groundx ./src/groundx -n eyelevel -f values.yaml --timeout 70m
```

Helm applies `--timeout` to each operation it waits for, including the
migration Job, not to the upgrade as a whole.

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

After a Helm timeout, check whether `<release>-schema-migration` is still
running before you run the upgrade again:

```sh
kubectl get job <release>-schema-migration -n <namespace>
```

The status column in that output exists only on newer clusters. To read the
Job's state on any cluster:

```sh
kubectl get job <release>-schema-migration -n <namespace> \
  -o jsonpath='{.status.active} {.status.conditions[?(@.type=="Failed")].reason}{"\n"}'
```

`1` means the Job is still running. A `Failed` reason means it failed:
`BackoffLimitExceeded` leaves pod logs to read, while `DeadlineExceeded` may
not. `NotFound` means it completed and Helm removed it.

Running the upgrade again deletes the previous migration Job, even one that is
still running, and starts a new one. Wait until the Job has finished first.

Already applied SQL is not rolled back when the Job fails. The runner resumes
partial additive upgrades. Application rollback retains added columns, indexes
and document receipts. Helm does not restore external database state. Retain
pending-document recovery dependencies when choosing the previous image.

## Argo CD and other GitOps tools

Argo CD renders the chart with `helm template`, so by default it never creates
the migration Job. Set `groundx.migration.gitOps: true` to render the migration
Secret and Job in every render. As with `helm upgrade`, it renders them only
when at least one Go workload is enabled. Argo CD runs Helm `pre-upgrade` hooks
as PreSync hooks, so the Job runs before Argo CD updates any Deployment, on
every sync, including the first.

The database, its credentials, the service account and the image pull Secrets
must exist before PreSync. Do not use `groundx.migration.gitOps` for a first
sync with the bundled MySQL: PreSync runs before Argo CD creates it.

The setting does not change `helm install` or `helm upgrade`. Helm runs the Job
only during an upgrade, with or without it.
