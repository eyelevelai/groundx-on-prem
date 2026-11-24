## Why

The layout and ranker inference Deployments each request a whole GPU (`nvidia.com/gpu: 1`) but set no rollout strategy, so Kubernetes uses its default rolling update. At 1 replica that starts the new pod before it stops the old one. On a cluster whose GPU node has no spare GPU, the new pod stays Pending while the old pod holds the GPU, and any upgrade that changes the pod template (image, or a `config-hash`, `config-models-hash` or `supervisord-hash` change) stalls until someone patches the Deployment or scales it to 0 and back. GX-117 makes the default upgrade complete on such clusters without manual steps.

## What Changes

- In the shared `src/groundx/templates/app/inference.yaml` (mirrored byte-for-byte in `helm/templates/app/inference.yaml`), when `updateStrategy` is empty and the rendered container resources ask for `nvidia.com/gpu` greater than 0 in `requests` or `limits`, render `strategy: {type: RollingUpdate, rollingUpdate: {maxSurge: 0}}`. The old pod stops first, then the new pod takes its GPU. `maxUnavailable` is left at the Kubernetes default (25%), which is 1 pod at 1, 2 and 4 replicas.
- In the same branch, render `progressDeadlineSeconds` as the service's termination grace period plus 600 seconds, using the existing `groundx.celeryWorker.gracePeriod` include already used for `terminationGracePeriodSeconds`. Layout and ranker default to 1500 seconds, and the value follows a `replicas.gracePeriod` override. Without it, a busy old pod that drains for its full grace period would trip the Kubernetes 600-second default and fail `kubectl rollout status` before the new pod could start.
- Read the GPU quantity as a number, not a raw value, because `resources` is an untyped object in `values.schema.json` and the quantity may arrive as an int, a float or a quoted string. A missing `resources`, `requests`, `limits` or key, a quoted `"0"`, or a non-numeric string counts as no GPU.
- Keep today's render unchanged when `updateStrategy` is set (type only, no deadline), when layout runs in CPU mode (the helper strips the GPU request), and for default summary (no GPU request).
- Tests in `src/groundx/tests/inference_test.yaml`: add `strategy` and deadline asserts to the existing non-snapshot cases, and one extensible case covering ranker default, a quoted quantity, explicit-override precedence, default summary, and a deadline derived from a `replicas.gracePeriod` override. The new assertions fail on today's chart.
- Hand-patch only the added lines in the affected `inference_test.yaml.snap` and `ranker_test.yaml.snap` blocks. No `-u` regeneration.
- `docs/upgrades.md`: document the new default, the outage on each upgrade (old pod drain plus model load), the opt-out `updateStrategy: RollingUpdate`, and `kubectl rollout status` as the completion check. Replace the now-stale line 216 ("With a GPU request, keep `updateStrategy: Recreate` unless a spare GPU is free").
- **Behaviour change (not a schema break):** with default values, layout and ranker (and summary, if an operator gives it a GPU request) have no running pod from the old pod's stop until the new pod is Ready, on each pod-template change. This is the cost the ticket accepts.
- No values keys, schema, helper, chart version or CHANGELOG change.

## Capabilities

### New Capabilities
- `inference-gpu-rollout-strategy`: GPU-requesting inference Deployments default to a rolling update that frees the GPU before the new pod starts, with a progress deadline that covers the old pod's drain; an explicit `updateStrategy` takes precedence.

### Modified Capabilities

None. `summary-inference-gpu-sizing` keeps its explicit-`Recreate` guidance for the 24 GB block and the 48 GB defaults, which stays valid; only the sentence in `docs/upgrades.md` that says a GPU request needs `Recreate` is corrected.

## Impact

- **Blast radius:** every environment that upgrades the chart. Only Deployments rendered by `inference.yaml` with a positive GPU request change (layout and ranker by default). The change adds only `spec.strategy` and `spec.progressDeadlineSeconds` and leaves `spec.template` unchanged, so upgrading does not restart these pods by itself; the new strategy applies at the next rollout that another pod-template change triggers (an image change or a `config-hash`, `config-models-hash` or `supervisord-hash` change). Default summary and CPU-mode layout render as before.
- **Cluster capacity:** at 1 replica, no pod serves for the drain plus model load on every later template change. With more replicas, at most 25% (rounded down, minimum 1) are unavailable at a time.
- **Opt-out and rollback:** explicit `updateStrategy: RollingUpdate` renders the type only, so the API server defaults `maxSurge` to 25% and the deadline to 600 seconds. Whether Helm's patch clears the previously rendered `maxSurge` and `progressDeadlineSeconds` is unverified; design will state the check.
- **Not covered:** a model download on upgrade (the `download-model` init container can run longer than the 600 seconds past the grace period).
- **Gate:** `.build/bin/validate-helm.sh` byte-compares `src/groundx/templates` against `helm/templates`, so the mirror must match.
- **Cross-service:** `groundx-studio-harness` documents the old guidance (manual `Recreate` or scale to 0). Its correction and eval case are a separate PR after this one reaches verify, and are not part of this change. See the workspace `openspec/changes/gx-117-upgrading-groundx-on-one-gpu-nodes/` for coordination.
- **Live proof:** ticket AC2 (upgrade on a one-GPU validation EKS cluster, before and after) runs outside the pipeline once both PRs exist.
- **Scope note:** the ticket puts summary's upgrade rollout out of scope, but the root cause is the same for any GPU-requesting Deployment, so summary with an explicit GPU request gets the new default. This is in the approved plan; default summary is untouched.
- **Open design questions:** none.

## Amendment 2026-11-24: summary on a GPU without a GPU request

Default summary also gets a strategy. This supersedes the statements above that default summary is unchanged (What Changes, Scope note).

- **Why:** the same stall hits summary, and `docs/upgrades.md` already described it for the 48 GB defaults. Review asked for one rule across the three inference services, which share one template.
- **Rule:** with `updateStrategy` empty, an inference pod that runs on a GPU (`deviceType` is not `cpu`) but asks for no `nvidia.com/gpu` renders `Recreate` and the same grace period + 600 deadline. `maxSurge: 0` cannot hold such a pod back: the scheduler does not see the GPU memory it shares. On a throwaway k3s cluster a pod with no GPU request was Ready at 2 s beside its old pod, which drained until 42 s; with a GPU request it stayed Pending until the old pod exited.
- **Opt-out:** `updateStrategy: RollingUpdate`. Multi-GPU summary installs that ask for the GPU, as `docs/upgrades.md` describes, keep `maxSurge: 0`. A summary pod with `topologySpreadConstraints` set, the guide's other multi-node setup, keeps the Kubernetes default: review pointed out the new default would otherwise take zero-downtime rolling away from it.
- **Rejected:** a per-node-group input saying whether a surge pod fits, and a live `lookup` of nodes. The chart has no node capacity value, and `lookup` returns nothing under `helm template` and fails the upgrade for a user without cluster-wide node access (tested on Helm 3.19.0).
- **Edge:** a layout or ranker pod in GPU mode that asks for no `nvidia.com/gpu` (for example a different GPU resource) also renders `Recreate`.
- **Tests:** one small new case (a summary spread across nodes keeps the default), plus 8 snapshot blocks, the summary asserts in the grace period case and one fixture line; ten mutations of the rule and one of the spread condition each fail the suite.
