# Managed application storage

The completed rollout is recorded in
[the Studio database switch](../../openspec/changes/archive/2026-09-14-switch-managed-records-to-studio/rollout.md).
New production app records use `groundx-studio`. Production files and cache
use the dedicated S3 bucket and `gx-managed-data-prod` cache. Development
records and files remain available; the unused development cache was removed.

`runner-policy.json`, `runner-trust.json`, and `service-account.yaml` record
the dedicated Workspace identity and its final storage permissions. They are
account-specific operator assets, not portable chart defaults. Database
administrator URLs belong only in the Workspace-specific Secret.

The chart's optional `workspace.managedData.mysqlSslCaConfigMap` names an
existing ConfigMap in the Workspace namespace with key `ca.pem`. The live
ConfigMap is `workspace-managed-db-ca-regions`, containing the public AWS RDS
certificates for both us-east-1 and us-west-2. The chart mounts this public trust
bundle read-only in all six Workspace processes. It does not create the
ConfigMap or enable managed storage by default.

`check-app-data.mjs` and `check-runner-startup.yaml` are historical probes
pinned to the disposable development project and runner build used during
rollout. That project is deleted. They are not a current smoke-test command
or a deployment recipe. The adjacent `managed-data-dev` directory records
the earlier development-only TLS prerequisites.

Do not apply these assets wholesale to the live release. Operator changes
require a current inventory and a scoped preview preserving unrelated workloads.
