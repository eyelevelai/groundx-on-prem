# Managed-data development prerequisites

These resources belong only to `groundx-studio-dev` in AWS account
`903713046261`, EKS cluster `eyelevel_890ng3` in `us-west-2`.
They do not deploy or update production workloads.

The namespace is quota-limited and cannot create load balancers or persistent
volume claims. A namespace alone does not isolate network traffic. The shared
cluster currently has network-policy enforcement disabled; do not claim these
resources establish network isolation.

Validate before applying with the explicit development namespace and cluster:

```sh
kubectl --context gx-prod-extract apply --dry-run=server -k ops/managed-data-dev
kubectl --context gx-prod-extract apply -k ops/managed-data-dev
```

`workspace-db-ca` contains only public AWS RDS certificates, downloaded from
https://truststore.pki.rds.amazonaws.com/us-east-1/us-east-1-bundle.pem.
Mount it read-only in the development runner and set both `MYSQL_SSL_CA_FILE`
and `MANAGED_DATA_MYSQL_SSL_CA_FILE` to the mounted PEM file. Those settings
require the runner's verified-TLS change. Database passwords and administrator
URLs belong in a separate development Secret, never this directory.

No database, cache, bucket, application credential, or running service is
created by this configuration. Restart only development workloads when replacing
the CA bundle. Removing these resources does not remove any database data.

The separate `check-database-tls.yaml` job tests both production connection
functions from the cluster using intentionally invalid, synthetic credentials.
An authentication rejection after verified TLS proves network reachability and
server identity, not database permissions or application readiness. It cannot
run queries or change data, has no Kubernetes credentials, and expires after
completion. Apply it separately after its server-side dry run:

```sh
kubectl --context gx-prod-extract apply --dry-run=server -f ops/managed-data-dev/check-database-tls.yaml
kubectl --context gx-prod-extract create -f ops/managed-data-dev/check-database-tls.yaml
kubectl --context gx-prod-extract -n groundx-studio-dev logs job/check-database-tls-d952718
```
