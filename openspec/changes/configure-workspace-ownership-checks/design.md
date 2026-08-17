# Configure Workspace Ownership Checks Design

## Decision

Add one chart value:

```yaml
workspace:
  ownershipChecksEnabled: true
```

The default is `true`. The chart renders it into the shared runner `config.py`:

```python
workspace_ownership_checks_enabled=True
```

That ConfigMap is mounted by the runner API and every worker. Existing config
hash annotations force their Deployments to roll when the value changes.

The runner also accepts `WORKSPACE_OWNERSHIP_CHECKS_ENABLED`. The direct
environment value takes precedence over the chart-rendered value, so either
configuration path works without a second authorization implementation.

## Contract

`src/groundx/values.schema.json` accepts only a boolean. The default source and
published mirror both set `true`. The helper also defaults to `true` so partial
values files cannot disable checks by omission.

## Rollout

1. Deploy a workspace-runner image that accepts the new setting.
2. Upgrade the chart with the value left at `true` and confirm every workspace
   pod becomes ready.
3. Set the value to `false` only in the internal environment that needs the
   bypass.
4. Confirm all workspace API and worker startup logs report the same effective
   setting.

An older runner image fails to import the rendered `config.py` because its
`Settings` constructor does not know the field. Chart and image ordering is
therefore required.

## Rollback

Set the value to `true` and let the ConfigMap hash roll the workspace pods. If
the runner image must also be rolled back, roll back the chart first so the old
image never receives the new constructor field.

## Validation

- `helm lint src/groundx`
- `helm template groundx src/groundx -f src/groundx/values/minikube/values.yaml`
- `helm unittest src/groundx`
- strict OpenSpec validation
- source and published-chart mirror comparison
