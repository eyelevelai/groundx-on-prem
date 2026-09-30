## Why

GX-61's production incident (one 93-page PDF, 11 layout attempts, `layout-process` pods
OOMKilled up to 16 times, `groundx-prod-eks` 2026-09-11) is fixed with two coordinated changes: a
bounded-retry fix in `ai-server`, and a durable memory fix that renders pages to disk instead of
holding a whole batch in memory (comment thread C2-C7, confirmed by three spike reports). The
disk-render path needs somewhere to put temp page files that (a) is guaranteed to exist without
an operator step, (b) cannot grow without bound and starve the node, and (c) is reliably swept
after the production failure mode — a whole-container restart, not a clean process exit, where
the dying container's filesystem stops being cleaned up until the pod itself is deleted. A plain
container-writable-layer temp directory does not survive that restart; a `PersistentVolumeClaim`
would block horizontal scaling (shared/bound storage, an affinity requirement) and is unnecessary
for data nothing needs to survive a pod restart. `groundx-on-prem` is the only place that can
supply the third option: a per-pod, disk-backed `emptyDir`, created and torn down with the pod by
Kubernetes itself, mounted and sized automatically on `helm upgrade`.

## What Changes

- Add a disk-backed (not memory-medium) `emptyDir` volume to every `layout-process` pod, mounted
  at a dedicated path (e.g. `/tmp/render`) as the render temp root. Created automatically on
  `helm upgrade` — no `PersistentVolumeClaim`, `StorageClass`, pod affinity, or manual operator
  step, and no constraint on horizontal scaling (per-pod volume, not shared/bound storage).
- Add one optional chart value, `layout.process.renderDiskBudgetMi` (integer MiB, `minimum: 1`,
  default `2048`), the per-process disk budget `ai-server` enforces as its primary OOM guard.
- Pass the mount path and the budget into the `layout-process` container as environment variables
  — `TMPDIR=<mount>` and `LAYOUT_RENDER_DISK_BUDGET_MIB=<budget>` — so the chart value is the
  single source for both the app's enforced budget and the volume's own ceiling.
- Always compute `emptyDir.sizeLimit` and `resources.requests.ephemeral-storage` from the same
  formula, `workers × threads × renderDiskBudgetMi + 1024` MiB (3072Mi at the 0.2.7 defaults of 1
  worker × 1 thread) — the 1 GiB reserve keeps the app's own budget below the volume ceiling, so
  the app refuses an oversized chunk before Kubernetes would evict the pod on disk pressure. The
  computed ephemeral-storage request **replaces** any user-supplied one; every other key under
  `layout.process.resources` is preserved unchanged (a copy, not a mutation, of `.Values`).
- Add the new key to `values.schema.json` under `layout.process` (`additionalProperties: false`
  there today), document its default in `values.yaml`, and mirror every changed file by hand into
  `helm/` (the manual `src/groundx/` → `helm/` sync this repo has no regen check for).
- Extend `src/groundx/tests/celery_test.yaml` and `helm/tests/`: default (no override), override
  (custom `renderDiskBudgetMi` — `sizeLimit`, the ephemeral request, and the env var all follow
  it), and multi-replica/HPA (confirms the volume stays per-pod and adds no shared/bound storage
  or affinity that would block scale-out). Snapshots are hand-patched for the new fields, never
  regenerated with `-u` (this repo's pinned `helm-unittest` v1.1.2 drops/reorders existing
  snapshot labels on direct `-u` regen — the GX-6 precedent's recorded method).
- `celery.yaml` itself is unchanged — it already renders any `env`/`volumes`/`volumeMounts`/
  `resources` keys a service's `.settings` helper supplies; only
  `groundx.layout.process.settings` in `layout-process.tpl` gains them. Only the `layout-process`
  Deployment is affected — the other layout workers sharing `celery.yaml` (`correct`, `map`,
  `ocr`, `save`) and the `api`/`inference` pods render from their own `.settings` helpers, which
  this change does not touch.
- Chart version bump and publish sequencing follow the GX-6 precedent (chart-first rollout,
  confirmed in design.md).

Backward compatible, no **BREAKING** change: the new schema field is optional with a default, and
either side of an old/new image × old/new chart pairing keeps working (a new image on an
unpatched chart falls back to the code's own default temp directory and budget; an old image on a
patched chart gets an emptyDir and env pair it simply does not read).

## Capabilities

### New Capabilities
- `layout-process-render-disk`: the `layout-process` pod's per-pod, disk-backed `emptyDir` render
  temp root — automatic mount/env wiring, the `renderDiskBudgetMi` chart value, the derived
  `sizeLimit`/ephemeral-storage-request sizing formula, and the horizontal-scaling and
  backward-compatibility guarantees around it.

### Modified Capabilities
(none — no existing `openspec/specs/` capability governs `layout-process`'s temp storage,
resources, or environment; `layout-ocr-timeout` covers the unrelated OCR-timeout config line, and
`layout-inference-pvc`/`layout-inference-cpu-resources` govern the separate `inference` pod, not
`process`.)

## Impact

- **Affected code**: `src/groundx/values.schema.json`, `src/groundx/values.yaml`,
  `src/groundx/templates/_helpers/app/layout-process.tpl` (the only template logic change —
  `celery.yaml` is unmodified), `src/groundx/tests/celery_test.yaml`, `src/groundx/tests/__snapshot__/*.snap`
  (hand-patched), `helm/tests/`, and the identical files mirrored by hand into `helm/`.
- **Affected environments**: every install of this chart once the patched `0.2.7` chart is
  published and adopted, including any downstream consumer once it re-vendors at a newer pinned commit (a consumer
  pinned to a fixed `0.2.7` commit does not get this change from this PR alone). The companion
  `ai-server` change (separate repo, same ticket) is what actually starts using the mount and
  budget; an unpatched `ai-server` image on a patched chart leaves the volume mounted but unused.
- **Blast radius / rollout**: only the `layout-process` Deployment gains env vars, a volume, a
  volume mount, and a resources.requests.ephemeral-storage change — every other layout
  workload (`api`, `correct`, `inference`, `map`, `ocr`, `save`) is untouched. `layout-process`
  pods roll once on upgrade (new env/volume/resources always render, even at the default budget);
  this is a one-time rolling restart gated by the existing readiness probe, not downtime. Chart-first
  (or together) rollout is required for the mount to exist before an `ai-server` image that reads
  it deploys; this is stated explicitly in both this PR body and the `ai-server` PR body, alongside
  the emptyDir justification (pod-scoped scratch storage created and deleted with the pod; the
  container's own writable filesystem only fails to clean up on a whole-container restart — the
  production OOMKilled path — leaving dead-container temp files on the node until the pod is
  deleted, while the emptyDir survives that restart so the new container's first render sweeps them
  in about 0.1s).
- **Data / stateful-resource impact**: none. The `emptyDir` holds only transient render-batch page
  files, is created and deleted with the pod (no `PersistentVolumeClaim`, no `StorageClass`, no
  data that must survive a pod restart), and final page images continue to go to file storage
  exactly as today.
- **Horizontal scaling**: not blocked. The volume is per-pod (`emptyDir`, not shared or
  `ReadWriteOnce`), adds no new affinity, node-selector, or `StatefulSet` requirement, and every
  layout-process replica gets its own independent mount; the HPA/multi-replica chart test proves
  this. The only new constraint is that pods-per-node is also bounded by node ephemeral-disk
  capacity at `workers × threads × budget + 1GiB` per pod — the cluster-sizing doc note (tracked
  for the harness-repo follow-up) states this rule; the cluster autoscaler adds nodes as usual.
- **Rollback**: reverting this change (or downgrading the chart) removes the volume, env vars, and
  resources override; an `ai-server` image that already assumes the mount falls back to its own
  default temp directory and budget when it is absent (the same fallback path an unpatched chart
  exercises today), so rollback is a standard `helm rollback` / PR revert with no data-path break.
- **Dependencies**: none upstream in `groundx-on-prem` itself. Downstream: `ai-server`'s disk-render
  path (same ticket, coordinated rollout, see this ticket's contract) and, after the patched
  `0.2.7` chart is published, `groundx-studio-harness` docs (`values-yaml.md`,
  `cluster-requirements.md`, `failure-modes.md`, `troubleshooting.md`) — out of scope for this
  proposal and this repo, and gated to merge only after publish per the GX-6 precedent.
- **Coordination**: open PR #119 (GX-22) touches the same `celery` snapshot file this change's
  hand-patched `layout-process` entries land in — design.md must confirm at implementation time
  whether #119 has merged and, if not, how the two snapshot edits are sequenced to avoid a
  collision.
- **Open design questions**: none identified from AGENTS.md, existing `openspec/specs/`, or the
  approved plan (decomposition.md Revision 1, item 3) — the budget-formula, env-var names, schema
  field name/bounds, and test coverage are already pinned by the approved plan. design.md still
  needs to record: the exact chart-version-bump number and publish-timing statement (GX-6
  precedent), the deepCopy mechanism chosen for merging the ephemeral-storage request without
  mutating `.Values.layout.process.resources`, and re-confirmation that `layout.process` schema's
  `additionalProperties: false` is the only schema gate this change must satisfy.

## Amendments

### 2026-09-29 — review round 4 fix (Q1): "leaves the volume mounted but unused" overstated the old-image behavior

- **Correction to the "Affected environments" bullet above** (line 81 as originally written; this
  note does not edit it): "an unpatched `ai-server` image on a patched chart leaves the volume
  mounted but unused" is not accurate. The old image's `pdf2image.convert_from_bytes` writes its
  one temporary PDF copy with `tempfile.mkstemp()` (`pdf2image.py:354`, confirmed by reading the
  installed package source), which with no explicit `dir=` resolves from the `TMPDIR` environment
  variable the patched chart now sets — so that one temp file does land on the mounted emptyDir.
- **What stays true:** the old image reads and enforces neither `LAYOUT_RENDER_DISK_BUDGET_MIB`
  nor any disk ceiling of its own, so the emptyDir's chart-computed `sizeLimit` is the only backstop
  against that image's temp usage until the companion `ai-server` change lands; the deployment is
  otherwise unaffected, matching the corresponding scenario amendment in
  `specs/layout-process-render-disk/spec.md`.
- **Same correction applies to the "Backward compatible, no BREAKING change" paragraph** earlier in
  this file, which likewise says "an old image on a patched chart gets an emptyDir and env pair it
  simply does not read" — read that parenthetical as: the old image's `pdf2image` temp file lands on
  the emptyDir via `TMPDIR`, but the image does not read or enforce `LAYOUT_RENDER_DISK_BUDGET_MIB`.
