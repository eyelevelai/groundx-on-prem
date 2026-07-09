# Expose Document Summary Image Limit

## Why

FRA-76 needs self-hosted deployments to tune the same document-summary page
image limit used by hosted `cashbot-go`. The runtime fix belongs in
`cashbot-go`; this chart change only renders the app config value so on-prem
operators can configure it through values.

## Blast Radius

- Affects chart rendering of the application `config.yaml`.
- Affects self-hosted clusters when the chart is upgraded and the app image
  contains the matching `cashbot-go` runtime support.
- Does not change Kubernetes workload shape, storage, services, RBAC, HPA, or
  stateful resources.
- Does not fix runtime behavior by itself if the deployed app image does not
  consume `engines.*.maxImages`.

## What Changes

- Permit positive integer `engines.default.maxImages` values in
  `src/groundx/values.schema.json`.
- Reject non-positive configured values during Helm schema validation.
- Render `maxImages` into the generated application `config.yaml` engine block
  in `src/groundx/templates/resources/config-yaml.yaml` only when an operator
  sets it.
- Mirror source chart changes to `helm/` during implementation.
- Update Helm snapshots if rendered output changes.

## Out Of Scope

- App-side enforcement. That is tracked in `cashbot-go` OpenSpec change
  `limit-doc-summary-page-images`.
- Changing summary model image limits or vLLM server kwargs.
- Changing pod resources, queues, HPA, or deployment topology.
- Editing generated snapshot files by hand.
- Publishing chart packages.

## Affected Environments

- Dev/staging/prod on-prem environments only after chart upgrade.
- Hosted cloud only if it consumes the same app config key outside this chart.

There is no data or stateful resource impact.

## Rollback / Rollforward

Rollback:

- remove or ignore `engines.default.maxImages`;
- or deploy the previous chart.

Rollforward:

- upgrade to the chart that renders the field;
- deploy an app image that consumes the field;
- set a deployment-specific value if the default 30 does not match the provider.

## Open Design Questions

None. The chart exposes config only. Runtime behavior is owned by `cashbot-go`.
