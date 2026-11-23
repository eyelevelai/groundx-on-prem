# Workspace

The `workspace` service family is optional and disabled by default. Enable it when the Partner API should provision managed code projects for GroundX Studio Harness generated projects. The runner is internal-only: agents call the Partner API, the Partner API calls the runner, and the runner owns managed repository creation, short-lived git sessions, fallback file operations, command execution, cleanup, and publish operations.

## Credentials

Set `workspace.enabled: true` and provide either `workspace.token` or `workspace.existingSecret`. When `workspace.token` is provided, the chart renders it into the generated GroundX `config.yaml` as `workspace.token`, renders it into the runner `config.py` as `runner_token`, and creates a `workspace-secret` containing `WORKSPACE_RUNNER_TOKEN` as the environment fallback. When `workspace.existingSecret` is provided, that secret must contain `WORKSPACE_RUNNER_TOKEN`; both the Partner API and workspace runner fall back to that environment value because the config files intentionally render the token empty. The internal runner URL is derived into GroundX `config.yaml` as `workspace.baseURL`, not stored as a secret.

## Storage

Workspace project metadata and operation state are stored in MySQL. The primary path creates a managed GitHub or GitLab repository from the scaffold, returns a short-lived repo-scoped git session, and expects agents to clone, edit, commit, and push locally. The optional secondary file API uses `/tmp/workspaces` only as a disposable checkout cache for server-side reads, writes, patches, commands, and diffs; Git remains the source of truth and cache loss is recoverable. The chart mounts a persistent volume claim for this cache, with a default capacity of 20Gi. `workspace.pvc.enabled` is ignored; it does not switch the cache to `emptyDir`. The PVC follows the same helper pattern as inference services: `cluster.pvClass` sets the storage class and `cluster.pvAccessMode` sets the access mode. Prefer `ReadWriteMany` when multiple workspace pods need to share the cache. The runner waits on Redis/Valkey and MySQL but does not wait on file storage because workspace artifacts are not part of the GroundX document file store. Runtime config rendered into `/app/config.py` uses chart helpers for MySQL, Redis/Valkey, command, and workspace defaults, with `workspace.publishDryRun` exposed as the normal safety toggle.

## Ownership checks

`workspace.ownershipChecksEnabled` defaults to `true`. Setting it to `false` skips runner ownership comparisons and project-list filtering, but leaves runner authentication and operation safety checks active. The shared ConfigMap change rolls the workspace API and every worker. Deploy a compatible workspace-runner image before using a chart version that renders this setting. Restore `true` before offering Workspace outside internal use.

## Managed application data

Managed project data is also disabled by default. For the hosted AWS path, set `workspace.managedData.enabled: true`, its AWS region, and the dev and prod S3 bucket, Redis endpoint, and Redis user-group values. To verify managed MySQL certificates with a public CA, set `workspace.managedData.mysqlSslCaConfigMap` to an existing ConfigMap containing the fixed key `ca.pem`; the chart mounts it read-only at `/var/run/config/workspace/mysql/ca.pem` in the Workspace API and all five workers. Use `workspace.existingSecret`; it must contain `WORKSPACE_RUNNER_TOKEN`, `MANAGED_DATA_RDS_ADMIN_CONNECTION_DEV`, and `MANAGED_DATA_RDS_ADMIN_CONNECTION_PROD`. Keep the RDS administrator URLs out of values files. Grant every Workspace component service account the least-privilege AWS permissions needed to manage the configured S3 prefixes, IAM users, and ElastiCache users. Enable dev first and verify allocation, republish, isolation, and confirmed deletion before enabling prod. Disabling the setting stops new reconciliation but does not delete existing app data.

## Publishing

Publish is dry-run by default. To enable real publish, set `workspace.publishDryRun: false`, configure the provider credentials owned by the runner service, and set the workflow or pipeline to trigger. For GitHub Actions:

```yaml
workspace:
  enabled: true
  token: "<internal-runner-token>"
  publishDryRun: false
  publishGithubWorkflowId: deploy.yml
  github:
    appId: "<github-app-id>"
    installationId: "<github-app-installation-id>"
    privateKeySecret:
      name: workspace-github-app
      key: private-key.pem
```

For GitLab, set `workspace.gitProvider: gitlab`, configure `workspace.gitlab.apiBaseUrl`, and provide a token via `workspace.gitlab.tokenSecret` or `workspace.gitlab.token`.

`privateKeySecret` is the production path: the chart mounts that existing secret only into workspace API and worker pods at `/var/run/secrets/workspace/github/private-key.pem`. For local or lower-environment testing, `workspace.github.privateKeyPem` can populate `GITHUB_APP_PRIVATE_KEY_PEM` in a generated `workspace-github-secret` that is mounted only into workspace API and worker pods. GitHub credentials are not mounted into the Partner API service.

## Autoscaling

Workspace autoscaling uses the same external metrics server as the rest of GroundX. Enable the metrics server and either global or per-component HPA settings so every rendered HPA metric has a matching `config.yaml` metric definition:

```yaml
metrics:
  enabled: true

cluster:
  hpa: true

workspace:
  enabled: true
  token: "<internal-runner-token>"
  command:
    queue: command_queue
    replicas:
      desired: 2
      threshold: 10
      throughput: 1250
```

The API emits `workspace-api:api` with a default threshold of `4000` and, by default, `workspace-api:throughput` with a default throughput of `50000`. The Partner API receives the runner URL from the workspace API helper, so the derived internal URL follows the same pattern as `extract-api`: `http://workspace-api.<namespace>.svc.cluster.local`. Worker HPAs emit `workspace-<worker>:task` and point the metrics server at the configured Celery queue for that worker; worker task thresholds default to `10`, worker targets default to `1`, and worker throughput defaults to `50000`. All of these values may be overridden per worker. Keep custom worker queue names in values rather than editing templates so the HPA and metrics-server config stay in sync.

## Verify the deployment

After deploying to a cluster, run `.build/bin/smoke-workspace-runner.sh` with the target kube context selected to verify the API, workers, cluster DNS, health endpoint, internal `/storage` status endpoint, and Partner API runner URL wiring.

## Implementation reference

The runner follows the standard Python microservice deployment pattern. The API uses the shared Gunicorn deployment template and the workers use the shared supervisord Celery deployment template. Workspace-specific resources provide `/app/config.py` (a `Secret`, since it carries credentials), `/app/gunicorn_conf.py` (a `ConfigMap`), and one supervisord config per queue (ConfigMaps): provision, workspace, command, publish, and cleanup. API knobs such as `threads`, `workers`, `timeout`, `timeoutKeepAlive`, `replicas`, `resources`, `node`, `serviceAccount`, and pod metadata live under `workspace.api`, matching the other Python API services. Worker knobs such as `queue`, `threads`, `workers`, `replicas`, `resources`, `node`, `serviceAccount`, and pod metadata live under each worker section: `provision`, `workspace`, `command`, `publish`, and `cleanup`.
