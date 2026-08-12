# Expose Extract Terminal Agent Trace Design

## Values Contract

The shared value is:

```yaml
extract:
  terminalAgentTraceEnabled: false
```

Each extract pod accepts the same optional override:

```yaml
extract:
  terminalAgentTraceEnabled: true
  api:
    terminalAgentTraceEnabled: false
  agent:
    terminalAgentTraceEnabled: true
  download:
    terminalAgentTraceEnabled: false
  save:
    terminalAgentTraceEnabled: false
```

The shared value defaults to `false`. Pod overrides have no chart default, so
omission means inherit the shared value.

## Precedence

Each pod-specific `.tpl` helper checks whether its pod block contains
`terminalAgentTraceEnabled`:

1. If present, use the pod value.
2. Otherwise, use `extract.terminalAgentTraceEnabled`.
3. If the shared value is absent, use `false`.

This must use `hasKey`, not Helm's `coalesce`. Helm treats boolean `false` as
empty, so plain `coalesce` would incorrectly ignore an explicit pod-level
`false` when the shared value is `true`.

## Rendering

The API, agent, download, and save settings helpers each add this entry to their
environment map:

```yaml
EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED: "true"
```

The existing Celery deployment template already renders environment maps for
agent, download, and save. The shared API deployment template will render the
same settings environment map after `POD_NAME`. Other API services are
unchanged because their settings do not provide this entry.

The agent helper merges this entry with its existing image-transport variables.

## Runtime Impact

Every extract process receives the effective value. Internal Arcadia AGE-272
owns the matching runtime behavior in the API, agent, download, and save
terminal failure owners. This chart-only change does not create artifacts.

No success-path logs or artifacts are added. Enabling the value only changes
behavior in compatible runtime paths that already consume it.

## Validation

- Schema accepts booleans at shared and pod scope and rejects other types.
- Default rendering sets the environment variable to `"false"` on all four
  extract deployments.
- Shared `true` renders `"true"` on all four deployments.
- A pod-level `false` overrides shared `true` only for that pod.
- A pod-level `true` overrides shared `false` only for that pod.
- Existing non-extract API snapshots remain functionally unchanged.
- `.build/bin/validate-helm.sh --junit` passes.
- Changed chart source files match their `helm/` mirrors.

## Rollout

This plan stops after chart validation and hands deployment to Internal Arcadia
AGE-272. That rollout must:

1. Verify the processed-layout prefix has encryption, blocked public access,
   least-privilege access, audit logging, and an effective lifecycle rule.
2. Prove each stage's bounded artifact and total deadline preserve callback or
   API response behavior.
3. Deploy a compatible extract image and this chart with capture disabled.
4. Verify all four workloads are ready and receive the intended effective
   setting.
5. Enable pods through their overrides, then use the shared value only after all
   four pod paths pass their rollout gates.
6. Verify successful requests write no terminal artifact. Inspect only natural
   production failures.

No deployment or chart publication is part of implementation.
