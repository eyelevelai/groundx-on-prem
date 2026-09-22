# Design

Add `extract.api.disruptionBudget.enabled`, disabled by default, and render a `policy/v1` PodDisruptionBudget with `minAvailable: 1` for `extract-api` when enabled. The selector uses the same `app: extract-api` label as the Deployment.

The hosted EKS values enable the budget and set `extract.api.replicas.desired` and `min` to two. HPA remains enabled with the existing maximum. This follows the existing production Workspace availability pattern without changing other API services or generic chart behavior.

Roll out through the normal hosted Helm deployment. Verify two ready replicas, an HPA minimum of two, and the disruption budget before any node maintenance. Roll back the three hosted values if scheduling capacity is insufficient. There is no migration or stateful-resource impact.
