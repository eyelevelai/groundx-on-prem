# GX-61: `layout-process` render temp storage is a per-pod `emptyDir`, sized from one chart value

## Status

Accepted (2026-09-29).

## Context

GX-61's production incident: one 93-page PDF drove `layout-process` to 11 layout attempts,
`OOMKilled` up to 16 times on `groundx-prod-eks` (2026-09-11), while holding a whole render batch
in memory. The durable fix — render pages to disk a few at a time instead of holding a whole batch
in memory (`ai-server` scope, not this repo's; see GX-61) — needs somewhere in every
`layout-process` pod to put temp page files, and this repo is the only place that can supply it:
`ai-server` has no chart-level control over a pod's volumes.

Two decisions belong to this chart, not to `ai-server`:

1. **What kind of volume.** The candidates were a `PersistentVolumeClaim`, the container's own
   writable layer (no explicit volume at all), and an `emptyDir`.
2. **How its size is derived.** Node ephemeral disk is finite and shared across every pod
   scheduled to it; an unbounded or hand-typed-per-environment volume size is either a
   node-exhaustion risk or an operational burden that drifts from the app's own enforced budget.

## Decision

**Volume kind: a per-pod, disk-backed `emptyDir`** (not `medium: Memory`, not a
`PersistentVolumeClaim`, not the bare container filesystem).

- A `PersistentVolumeClaim` is rejected: it introduces shared or `ReadWriteOnce`-bound storage,
  typically an implicit affinity to whichever node/zone first bound it, and an operator
  provisioning step — all three are unacceptable for data that never needs to survive a pod
  restart, and the affinity requirement directly conflicts with this ticket's horizontal-scaling
  requirement (every `layout-process` replica must be schedulable independently).
- The bare container writable layer is rejected because it does not survive the actual production
  failure mode: a whole-container restart (`OOMKilled`). On a container restart, the new container
  gets a fresh writable layer — the dead container's own layer, and any temp files written into it,
  stays on the node (invisible to the new container, which cannot clean up files it never had
  access to) until the kubelet garbage-collects it or the pod itself is deleted. An `emptyDir`, by
  contrast, is deleted only when the **pod** itself is deleted, so it survives exactly that
  container-restart boundary — a container restart inside a still-running pod leaves the
  `emptyDir`'s prior contents in place for the new container to sweep immediately.
- An `emptyDir` satisfies both constraints: it is created and deleted with the pod (no operator
  step, no cross-pod sharing, no scheduling affinity), and it survives exactly the restart
  boundary this incident needs it to survive (container restart, not pod deletion) — the new
  container's first render sweeps the previous container's dead files in about 0.1s instead of
  waiting for the pod to be deleted.

**Sizing: one chart value (`layout.process.renderDiskBudgetMi`) is the sole input to three
independently-rendered fields** — `emptyDir.sizeLimit`, `resources.requests["ephemeral-storage"]`,
and the `LAYOUT_RENDER_DISK_BUDGET_MIB` container env `ai-server` reads — computed as `workers ×
threads × renderDiskBudgetMi + 1024` MiB. The chart owns the volume's ceiling and the scheduling
request; `ai-server` owns enforcing the per-process budget against that same number. The 1 GiB
reserve is deliberate: it keeps the app's own enforced budget strictly below the volume's ceiling,
so the app refuses an oversized render chunk with a normal application-level error before
Kubernetes would evict the pod on disk pressure — eviction is a much coarser, harder-to-diagnose
failure than an application error.

## Consequences

- **New, real constraint: node ephemeral-disk capacity now bounds `layout-process` pods-per-node**,
  independent of and in addition to CPU/memory. A node whose allocatable ephemeral storage is
  small relative to its CPU/memory capacity now schedules fewer `layout-process` pods than
  CPU/memory alone would allow. This chart cannot see or enforce node disk size; the
  `groundx-studio-harness` `cluster-requirements.md` follow-on (out of scope for this repo, gated
  to merge only after this chart's publish) is where operators are told the sizing rule.
- **Reversible.** Reverting this change (or downgrading the chart) removes the volume, env vars,
  and the `resources.requests["ephemeral-storage"]` override; a companion `ai-server` image that
  already assumes the mount falls back to its own default temp directory and budget when the
  mount is absent — the same fallback path an unpatched chart exercises today. Rollback is a
  standard `helm rollback` / PR revert with no data-path break, because nothing in the `emptyDir`
  is ever the only copy of anything — final page images continue to go to file storage exactly as
  today.
- **Establishes a reusable pattern**, not a one-off: any future GroundX workload that needs
  bounded, pod-scoped scratch disk with the same "survive a container restart, not a pod
  deletion" requirement can follow the same `emptyDir`-plus-chart-computed-`sizeLimit`-and-request
  shape, rather than each such need independently re-deriving whether a PVC is warranted.
- **Does not decide `ai-server`'s rendering algorithm** (per-process owner directories, the
  dead-owner sweep, page-count checks, hard-kill timeouts around `pdftoppm`/`pdfinfo`) — those are
  `ai-server`'s own design decisions, recorded in that repo's `design.md`, not this ADR.
