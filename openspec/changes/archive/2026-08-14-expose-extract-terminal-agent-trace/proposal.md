# Expose Extract Terminal Agent Trace

## Why

The extract runtime uses `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED` to retain
bounded private evidence after terminal failures, but chart users cannot
configure it. The setting must be available to every extract pod, with one
shared default and an optional override for each pod.

## Blast Radius

- Changes the pod template for extract API, agent, download, and save
  deployments.
- Any changed effective value rolls only the affected extract deployments.
- Does not add resources, change queues, storage, RBAC, HPA, or stateful data.
- Runtime behavior requires the matching Internal Arcadia AGE-272 extension.
  The chart change alone only injects configuration.

## What Changes

- Add shared `extract.terminalAgentTraceEnabled` with default `false`.
- Add optional `terminalAgentTraceEnabled` overrides under `extract.api`,
  `extract.agent`, `extract.download`, and `extract.save`.
- Resolve the effective value inside each pod helper. An explicitly configured
  pod value wins over the shared value, including explicit `false`.
- Render the effective value as
  `EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED` in every extract pod.
- Add environment rendering to the shared API deployment template, matching the
  existing Celery deployment template.
- Mirror source chart changes into `helm/`.

## Out Of Scope

- Implementing terminal artifact capture. Internal Arcadia owns that runtime.
- Adding an arbitrary environment-variable map.
- Changing the extract application image.
- Deploying or publishing the chart.

## Runtime Dependency

Internal Arcadia AGE-272 owns terminal behavior for API, agent, download, and
save. The chart is not complete delivery until a compatible extract image uses
the effective setting in each pod's terminal failure owner. API diagnostics use
one best-effort one-second transport budget without changing the general request
timeout. The storage SDK does not provide a hard wall-clock timeout.
Celery diagnostics are terminal only after callback publication cannot retry or
requeue the task.

## Affected Environments

Dev, staging, production, and self-hosted clusters are affected only after a
chart upgrade. There is no data migration or stateful resource impact.

## Rollback / Rollforward

Rollback by setting the shared and pod values to `false`, or by deploying the
previous chart. Roll forward only through the Internal Arcadia AGE-272 storage,
budget, security, readiness, and natural-failure gates.

## Open Design Questions

None.
