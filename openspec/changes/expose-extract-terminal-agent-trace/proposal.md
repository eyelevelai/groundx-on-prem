# Expose Extract Terminal Agent Trace

## Why

The extract runtime already reads
`EXTRACTION_TERMINAL_AGENT_TRACE_ENABLED`, but chart users cannot configure it.
The setting must be available to every extract pod, with one shared default and
an optional override for each pod.

## Blast Radius

- Changes the pod template for extract API, agent, download, and save
  deployments.
- Any changed effective value rolls only the affected extract deployments.
- Does not add resources, change queues, storage, RBAC, HPA, or stateful data.
- Runtime behavior still requires an extract image that consumes the environment
  variable. The current terminal artifact path runs in agent tasks.

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

- Adding terminal artifact capture to API, download, or save task paths.
- Adding an arbitrary environment-variable map.
- Changing the extract application image.
- Deploying or publishing the chart.

## Affected Environments

Dev, staging, production, and self-hosted clusters are affected only after a
chart upgrade. There is no data migration or stateful resource impact.

## Rollback / Rollforward

Rollback by setting the shared and pod values to `false`, or by deploying the
previous chart. Roll forward by deploying the updated chart and enabling the
shared value or selected pod overrides.

## Open Design Questions

None.
