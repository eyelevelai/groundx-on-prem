See `proposal.md` for the full current-state analysis (why an `emptyDir` and not a `PersistentVolumeClaim`,
the production OOMKilled failure mode this volume must survive, and the plan-gate decisions this
design carries forward from `decomposition.md` Revision 1 item 3).

## Goals / Non-Goals

**Goals:**
- Wire a per-pod, disk-backed `emptyDir` render-temp volume into every `layout-process` pod,
  mounted and sized automatically on `helm upgrade`, with one chart value
  (`layout.process.renderDiskBudgetMi`) as the single source for both the app's enforced disk
  budget and the volume's own ceiling.
- Keep the change additive and reversible: optional schema field with a default, no new subsystem,
  no PVC, no operator step, no constraint on horizontal scaling.

**Non-Goals:**
- No change to `layout.process.batchSize` or its path into `ai-server`'s `config.py`
  `minBatchSize` (plan-gate decision, unchanged by this change).
- No rendering-algorithm decisions (per-process owner directories, sweep, page-count checks,
  hard-kill timeouts) — those are `ai-server`'s design, not this chart's.
- No fix to the pre-existing `helm/` ↔ `src/groundx` drift-check gap (`AGENTS.md` "Repo-specific
  gotchas") — this change follows the existing manual-mirror convention, it does not fix it.
- No node/cluster disk-capacity-planning documentation — that lands in
  `groundx-studio-harness` `cluster-requirements.md` (Level 2, gated to merge only after this
  chart's publish; out of scope for this repo and this proposal).

## Decisions

- **Mount path and volume name.** Dedicated path `/tmp/render`, volume name `render-temp`. No
  existing `layout.process` volume or mount uses this path (`celery.yaml:206-224` renders only
  `config-volume` and `supervisord-volume` for this service today), so there is no collision to
  resolve.

- **Schema property: `layout.process.renderDiskBudgetMi`, `{"type": "integer", "minimum": 1}`,
  default `2048`.** Inserted alphabetically between the existing `queue` and `replicas`
  properties in `values.schema.json`'s `layout.process` block (`queue` at line 1040,
  `replicas` at line 1041) — the same alphabetical-sibling convention `layout.ocr.timeout`
  followed in the GX-6 precedent. `layout.process` already declares
  `"additionalProperties": false`, so this is the only schema gate the new field must satisfy;
  no other block needs a change (`resources` is already free-form, so `ephemeral-storage`
  requires no separate schema entry).

- **Env var names: `TMPDIR` and `LAYOUT_RENDER_DISK_BUDGET_MIB`.** `TMPDIR` is the value
  `ai-server`'s own render path already falls back to reading via `tempfile.gettempdir()` (no
  chart-side naming choice here — it is the interpreter/OS convention `ai-server`'s design relies
  on). `LAYOUT_RENDER_DISK_BUDGET_MIB` is a new, chart-owned name; `ai-server` treats its absence
  as "no override" and defaults to `2048` itself (the same number this chart defaults to), so a
  new image on an unpatched chart and an old image on a patched chart both keep working (see the
  backward-compatibility scenarios in `specs/layout-process-render-disk/spec.md`).

- **`renderDiskBudgetMi` is the one source for three rendered fields, never three separate
  inputs.** `emptyDir.sizeLimit`, `resources.requests["ephemeral-storage"]`, and the
  `LAYOUT_RENDER_DISK_BUDGET_MIB` env value are all computed from the same
  `layout.process.renderDiskBudgetMi` in `groundx.layout.process.settings`
  (`templates/_helpers/app/layout-process.tpl`) — `workers × threads × renderDiskBudgetMi + 1024`
  MiB for the first two, the raw value for the third. `celery.yaml` itself needs no change: it
  already renders any `env`/`volumes`/`volumeMounts`/`resources` keys a service's `.settings`
  helper supplies (`celery.yaml:27-39,107-115,140-146,171-175,206-224`) — only
  `groundx.layout.process.settings` gains them.

- **deepCopy mechanism for the resources merge — follow the `layout-inference.tpl:239`
  precedent exactly.** `dig`/`get` on a Helm values map returns a reference into `.Values`, not a
  copy; `set`-ing a key on that reference would mutate `.Values.layout.process.resources` itself
  and leak across every subsequent template evaluation in the same render (`layout-inference.tpl`
  already solved this for its own resources-merge case: `{{- $resources := deepCopy (get $in
  "resources") -}}` at line 239, then `set`/`unset` only on the local copy, only writing it back
  to `$cfg` — never back to `$in` or `.Values`). `layout-process.tpl`'s new merge follows the same
  shape: `$resources := deepCopy (dig "resources" dict $in)`, then
  `set $resources "requests" (merge-set the computed ephemeral-storage key into a deep copy of
  the existing requests map, same reasoning)`, then `set $cfg "resources" $resources`. Every
  other key under `layout.process.resources` (e.g. `requests.cpu`, `requests.memory`, any
  `limits`) is copied forward unchanged; only `requests["ephemeral-storage"]` is ever
  overwritten.

- **Chart version and publish convention — GX-6 precedent, confirmed directly against this
  repo's own history, not assumed.** `Chart.yaml`'s `version`/`appVersion` (`0.2.7`) is **not**
  bumped inside this OpenSpec change's own commits, matching GX-6: PR #122
  (`gx-6-expose-ai-server-ocr-timeout-ocrtimeout-in-the-helm-chart`, merged as
  `49c4ad63`) landed with no change to `src/groundx/Chart.yaml` at all, and the `helm/` mirror's
  `Chart.yaml` is already further behind (`version: 0.2.6`) than `src/groundx`'s `0.2.7` even
  after that merge — confirming the mirror's version field is not kept in lockstep with every
  merge either. Publishing (`src/build.sh`: `helm package groundx -d build` →
  `helm repo index build --url https://registry.groundx.ai/helm` → `aws s3 cp … --recursive`) is
  a maintainer-only, `PRIVILEGED`, human-run release step, decoupled from individual change
  merges — this OpenSpec change's tasks touch only `src/groundx/` (and its `helm/` mirror
  content, not `helm/Chart.yaml`'s version field) and never invoke `src/build.sh`. The
  `groundx-studio-harness` documentation follow-on (Level 2) is gated on that separate,
  human-triggered publish having happened — not on this PR merging.

- **Sequencing with open PR #119 (GX-22, `gx-22-on-prem-helm-unittest-toolchain-pin-0.2.7`,
  confirmed OPEN, not merged, as of this authoring pass).** Diffed directly against
  `origin/0.2.7`: #119 does **not** touch `src/groundx/tests/__snapshot__/celery_test.yaml.snap`'s
  content at all — its 21 changed files are new verification tooling
  (`.build/bin/verify-helm-snapshot-stability.py`, `.build/bin/verify-helm-unittest-plugin-version.py`,
  a pinned-binary checksum, `.gitattributes` CRLF rules, and `.build/bin/validate-helm.sh`
  wiring for them) plus its own OpenSpec change docs — no collision on the snapshot bytes this
  change hand-patches. The risk #119 does introduce is **process**, not content: it adds a
  snapshot-stability verifier and a CRLF-checkout guard that this change's hand-patched
  `celery_test.yaml.snap` edits do not yet need to satisfy (they don't exist on this branch yet).
  Recommended sequencing, stated in the PR body: merge whichever of the two lands first; the
  other rebases before merging. If #119 merges first, this change's task 3 (snapshot patch) runs
  its verification through the newer toolchain-pinned `validate-helm.sh` (a strictly stronger
  gate, not a conflicting one). If this change merges first, #119's rebase picks up the patched
  `celery_test.yaml.snap` lines as ordinary base content — its own diff doesn't touch them, so no
  merge conflict is expected either way; this is a sequencing note, not a blocking dependency.

- **`emptyDir` justification text — for both this PR's body and `ai-server`'s companion PR body
  (user-directed content, comment C6/C7 plus the Q&A log's item 21).** Record it here so both PRs
  quote it identically:

  > This uses a Kubernetes `emptyDir` volume as pod-scoped scratch storage — not a
  > `PersistentVolumeClaim` and not bound to any node or external volume. It is created and
  > deleted with the pod. The production failure mode this exists for is a **whole-container
  > restart** (the `layout-process` container getting `OOMKilled` and restarted by the kubelet),
  > not a clean process exit — and a plain container-writable-layer temp directory does **not**
  > survive that restart; the dying container's filesystem stops being cleaned up until the pod
  > itself is deleted, which can leave dead render-temp files on the node for as long as that pod
  > lives. The `emptyDir` survives a container restart within the same pod (Kubernetes tears it
  > down only when the **pod** is deleted, not on a container restart inside it), so the new
  > container's first render sweeps the previous container's dead files in about 0.1s instead of
  > leaving them until the next pod deletion. This is the durable reason for the volume, not
  > convenience: a `PersistentVolumeClaim` would add shared/bound storage and an affinity
  > requirement neither this data (nothing in it needs to survive a pod restart) nor horizontal
  > scaling can afford.

- **No `helm/`-side render-formula divergence risk beyond the existing manual-mirror gap.** The
  formula and helper logic are authored once in `src/groundx/templates/_helpers/app/layout-process.tpl`
  and mirrored by hand into `helm/templates/_helpers/app/layout-process.tpl` — both files are
  byte-identical today (confirmed directly: `diff src/groundx/templates/_helpers/app/layout-process.tpl
  helm/templates/_helpers/app/layout-process.tpl` and the same for `templates/app/celery.yaml`
  both exit 0), so this change's mirror task is a plain copy of the same edit, not a
  reconciliation of prior drift.

- **No new ADR beyond the one this change adds.** This change **does** introduce a new,
  reusable pattern (a chart-value-driven `emptyDir` sized from a per-process disk budget) with
  fleet-wide capacity-planning consequences (node ephemeral-disk sizing now bounds
  `layout-process` pods-per-node), which is a materially different bar than GX-6's single
  additive timeout value — see `docs/adr/0001-layout-process-render-disk.md` for the recorded
  decision (emptyDir vs. `PersistentVolumeClaim`, and the chart-owns-the-ceiling /
  app-owns-the-budget split). This design.md does not restate that ADR's content.

- **Cross-service shape:** see `contract.md` (workspace-level) for the full producer/consumer
  shapes of the `TMPDIR`/`LAYOUT_RENDER_DISK_BUDGET_MIB` touchpoint and the sizing-constant
  touchpoint with `ai-server`; not duplicated here.

## Risks / Trade-offs

- **`helm/` mirror still has no drift-check tooling.** This change is mirrored by hand into
  `helm/`, same as every other chart change — the underlying gap (no regen script, no CI drift
  check between `src/groundx` and `helm/`) is out of scope and remains a known repo-wide risk.
- **Node ephemeral-disk capacity is a new, real constraint this change introduces.** Every
  `layout-process` pod now reserves `workers × threads × renderDiskBudgetMi + 1024` MiB of node
  ephemeral disk (3072Mi at defaults); a node whose allocatable ephemeral storage is small
  relative to its CPU/memory capacity now caps `layout-process` pods-per-node below what CPU/
  memory alone would allow. This chart cannot see or enforce node disk size — the
  `groundx-studio-harness` `cluster-requirements.md` follow-on (Level 2, out of scope here) is
  where the sizing rule for operators is documented.
- **All 13 `matchSnapshot` `celery_test.yaml` cases that render `layout-process` need hand-patch,
  not just the "default" one — corrected during implementation from this design's original count
  of 12.** A literal grep for `name: layout-process` finds exactly 24 occurrences (2 per block ×
  12 blocks: `default`, `empty`, `aws`, `openshift`, `minikube`, `existing`, `extract`,
  `extract.ingest`, `extract.oai`, `cloud`, `phoenix`, and `shared Google credentials`) and was
  originally mistaken for the complete set. `metadata: celery` renders the identical
  `groundx.layout.process.settings` pod too, just under a renamed container (`name:
  myapp-process`, via that test's `layout.serviceName: myapp` override) — a literal-string grep
  cannot see it, but the pod still needs the same env/resources/volume patch, at a *different*
  computed value (`values.metadata.yaml` also overrides `layout.process.workers: 2` and
  `layout.process.threads: 2`, so its budget renders as `9216Mi`, not the `3072Mi` default — this
  design's original "no test values file overrides workers/threads" premise was also wrong).
  `workspace-enabled: celery` was originally listed among the 12 but does **not** need patching:
  it layers on top of `values.disabled.yaml`, which sets `layout.process.enabled: false`, and
  `values.workspace.enabled.yaml` never re-enables it, so no such Deployment renders there at all
  (confirmed alongside `disabled: celery`, which is correctly excluded). Missing any of the 13 is
  a silent stale-snapshot pass at review time, not a render failure — task 3 in `tasks.md`
  enumerates all 13 explicitly rather than patching only the most visible one.
- **`renderDiskBudgetMi` is fixed as an integer-MiB unit, not a `resource.Quantity` string
  (`"2Gi"`).** This keeps the Helm formula plain integer arithmetic (`mul`/`add`, no `resource.Quantity`
  parsing in Sprig), matching the plan-gate decision (`decomposition.md` Revision 1, item 3). The
  trade-off is a slightly less idiomatic Helm value shape than a native quantity string; accepted
  because both `ai-server` (`LAYOUT_RENDER_DISK_BUDGET_MIB`, a plain env-var int) and this chart's
  formula need the same integer, and a `resource.Quantity` string would need parsing on the
  `ai-server` side for no benefit.

## Amendments

### 2026-09-29 — review round 1 fix (G1, G2)

- **New decision: `layout.process.resources.limits["ephemeral-storage"]` IS parsed, in one narrow
  place, despite the decision above against `resource.Quantity` parsing.** That decision is about
  `renderDiskBudgetMi` (a chart *input*, kept a plain integer). The new guard added in this fix
  round instead reads an *operator-supplied* `resources.limits["ephemeral-storage"]` string — a
  standard Kubernetes quantity (`"1Gi"`, `"500Mi"`, a bare byte count) — which cannot itself be a
  plain integer-MiB value, since the operator may write it in whatever unit they already use.
  `groundx.layout.process.storageMi` (`templates/_helpers/app/layout-process.tpl`) converts it to
  MiB for comparison against the computed request: it recognizes the binary suffixes `Ki`/`Mi`/`Gi`/
  `Ti` and the decimal suffixes `K`/`M`/`G`/`T`, plus a bare numeric byte count, and `fail`s closed
  (see the guard-change-class "fail closed" rule) on any value it cannot parse (e.g. exponential
  notation) rather than silently skipping the check.
- **New decision: the `workers`/`threads` guard is a template-level `fail`, not a schema
  `minimum`.** `workers`/`threads` are declared once in `values.schema.json` and shared across
  every Celery-style service (`layout.process`, `layout.correct`, `ranker.inference`, …); adding a
  schema `minimum: 1` there would tighten every sibling service's contract, which is out of this
  ticket's scope. The guard is scoped to `groundx.layout.process.settings` instead, firing only for
  `layout.process`'s own render-disk formula (`workers × threads × renderDiskBudgetMi + 1024`),
  which is the one place a negative value would render a negative-sized `emptyDir`/`ephemeral-storage`
  quantity.
- **Both guards fire during `groundx.layout.process.settings`'s evaluation**, which Helm's chart-wide
  render always reaches through two call sites (`templates/app/celery.yaml` and
  `templates/resources/layout-supervisord-conf.yaml`) — a `helm template`/`helm upgrade` therefore
  fails the whole release, not just the `layout-process` Deployment, on either violation. This
  matches the "reject before state" polarity required for this class of input (see `spec.md`'s new
  requirements) and the existing `renderDiskBudgetMi` schema-`minimum` precedent already in this
  chart, which fails the same way for the same reason.

### 2026-09-29 — review round 2 fix (O1)

- **Correction to the round 1 amendment above: `groundx.layout.process.storageMi` now parses the
  full Kubernetes storage-quantity grammar, not the narrower set originally shipped.** Round 1's
  text above states the guard "recognizes the binary suffixes `Ki`/`Mi`/`Gi`/`Ti` and the decimal
  suffixes `K`/`M`/`G`/`T`... and `fail`s closed... on any value it cannot parse (e.g. exponential
  notation)". Both are corrected by this round: `K` (uppercase) was never a valid Kubernetes
  decimal suffix — the only valid lowercase-decimal form is `k` — so round 1 shipped with a bug
  that *wrongly accepted* `K` and offered no `P`/`E`/`Pi`/`Ei` suffixes at all; and rejecting
  exponent form was itself a gap, not a deliberate design choice, since Kubernetes quantities
  (`"129e6"`) and a plain unquoted number from a values file both need it. The helper now accepts
  binary `Ki`/`Mi`/`Gi`/`Ti`/`Pi`/`Ei`, decimal `k`/`M`/`G`/`T`/`P`/`E` (lowercase `k` only —
  uppercase `K` is rejected, closing the round 1 bug), a bare byte count, exponent form (`e`/`E`),
  and a native YAML number (`float64`/`int`/`int64`, as arrives from an unquoted values-file
  entry) — converted via `printf "%.0f"` rather than Go's default `%v` formatting, which switches
  to scientific notation for a large byte count and made the pre-fix helper reject its own
  input (`4294967296` rendered as `"4.294967296e+09"` and failed to parse). Still `fail`s closed,
  same named message, on anything else.
- **No change to the "one narrow place" scope decision.** This remains the only place in the chart
  that parses an operator-supplied Kubernetes quantity string; `renderDiskBudgetMi` itself is still
  a plain integer-MiB chart input, unaffected by this round.
