# Design

Add `disruptionBudget.enabled`, disabled by default, to every API values block: `groundx`, `extract.api`, `layout.api`, `ranker.api`, `summary.api`, and `workspace.api`. The shared Python API renderer and the shared Go service renderer emit a `policy/v1` PodDisruptionBudget with `minAvailable: 1` when a service helper passes the enabled setting. Each selector uses the same `app` label as its Deployment.

The hosted EKS values enable the budget for `extract-api`. Its desired and minimum replicas become two. `groundx` and `workspace-api` remain disabled because they have one replica. `layout-api` and `summary-api` are disabled. `ranker-api` is suppressed by `mode: ingest`, regardless of the stale ranker settings in that file. Generic chart behavior remains unchanged.

Roll out through the normal hosted Helm deployment. Verify the extract API replica count, HPA minimum, and budget before any node maintenance. Roll back the hosted settings if scheduling capacity is insufficient. There is no migration or stateful-resource impact.
