# Fix Ranker Inference HPA Readiness

## Why

The ranker image now publishes worker-capacity metrics, but the Helm chart still
uses a process check for readiness. After an idle period, worker records expire
and the HPA loses the capacity signal it needs to scale before the current pod is
saturated.

Ranker inference should use the same HTTP health contract as layout and summary
inference. Hosted HPA settings should also begin scaling earlier while keeping
one always-on replica.

## Blast Radius

- Changes ranker inference readiness and liveness probes from process checks to
  the existing HTTP health server.
- Changes hosted ranker HPA scale-up sensitivity and timing.
- Affects ranker inference rollouts in environments that adopt these chart and
  image changes.
- Does not change search request routing, ranker model behavior, GPU node type,
  node groups, Cluster Autoscaler, secrets, or stateful resources.

The chart currently uses `Recreate` for the hosted ranker deployment, so a
deployment can briefly remove EKS ranker capacity. This change will not be
deployed as part of implementation.

## What Changes

- Make ranker inference expose and use HTTP `/alive` and `/health` probes,
  matching layout and summary inference.
- Keep `/health` unavailable until the configured ranker workers have
  registered, so polling preserves their capacity records.
- Keep hosted ranker HPA minimum at 1 and maximum at 4.
- Set the hosted ranker HPA target to `0.4`.
- Set the hosted ranker scale-up cooldown to 15 seconds.
- Keep the existing ranker throughput sizing values unchanged.
- Add focused AI-server and Helm tests.
- Mirror chart source changes into `helm/`.

## Out Of Scope

- Deploying these changes.
- Changing GPU instance type, node group size, node labels, or scheduling.
- Changing or upgrading Cluster Autoscaler.
- Changing search fanout, OpenSearch candidates, model code, or API routing.
- Changing secrets.
- Changing the hosted ranker `Recreate` update strategy.

## Affected Environments

- The tracked chart change applies to environments that enable ranker
  inference.
- The HPA tuning applies to the hosted EKS values file only.
- Dev, staging, and production are unaffected until an operator deploys the
  matching chart and ranker image.

There is no data or stateful resource impact.

## Rollback / Rollforward

Rollback:

- deploy the previous chart and ranker image;
- restore the previous hosted HPA target and cooldown.

Rollforward:

- build the ranker image with worker health reporting;
- render and inspect the chart;
- deploy to a non-production environment and confirm health and HPA metrics;
- promote separately after an explicit production approval.

## Open Design Questions

None. The approved scope is limited to ranker health polling and HPA behavior.
