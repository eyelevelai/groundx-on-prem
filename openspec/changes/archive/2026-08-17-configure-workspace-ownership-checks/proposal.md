# Configure Workspace Ownership Checks

## Why

The workspace runner now supports a temporary ownership-check switch for
internal-only use. The Helm chart must expose that setting so operators can
configure every runner API and worker pod from values.

## Blast Radius

- Changes the workspace runner `config.py` ConfigMap and rolls all six workspace
  deployments when the chart is upgraded.
- Does not change services, storage, RBAC, queues, secrets, or database state.
- Requires a compatible workspace-runner image before this chart version is
  installed. Older images reject the new `Settings(...)` argument at startup.

## What Changes

- Add `workspace.ownershipChecksEnabled`, boolean, default `true`.
- Render it as `workspace_ownership_checks_enabled` in runner `config.py`.
- Mirror source chart files into the published `helm/` chart.
- Test default `true`, explicit `false`, and strict schema rejection.

## Out Of Scope

- Authorization logic, owned by `groundx-workspace-runner`.
- Cashbot changes or database migrations.
- Deploying or publishing the chart.

## Affected Environments

Any dev, staging, production, or self-hosted cluster with `workspace.enabled:
true` rolls the workspace API and workers on chart upgrade. No stateful resource
changes occur.

## Rollback And Rollforward

Roll forward by deploying the compatible runner image, then upgrading the chart.
Set `workspace.ownershipChecksEnabled: false` only while Workspace use is
internal.

Roll back by setting the value to `true`, then rolling back the chart before
rolling back the runner image. Stored ownership data is unchanged.

## Open Design Questions

None.
