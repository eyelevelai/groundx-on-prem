See proposal.md for the full current-state analysis (existing `layout.ocr` schema/helper/render
shape, the FRA-115 producer, and the plan-gate decisions this design carries forward).

## Goals / Non-Goals

**Goals:**
- Expose `layout.ocr.timeout` as a bounded, schema-validated Helm value that renders unquoted as
  `ocrTimeout=<int>` into the existing `layout-config-py-map` Secret's `config.py`, in both
  `src/groundx` and its `helm/` mirror, with no behavior change for any deployment that leaves it
  unset.

**Non-Goals:**
- No new subsystem, service, queue, or lifecycle. No change to `image_to_osd`/`correct.py`
  timeouts (GX-7 scope), no `layout.ocr.credentials`/OCR-type behavior change, no exposure of
  Celery's `TaskTO` itself (out of scope — see Decisions).
- No `helm/` ↔ `src/groundx` drift-check tooling — this change follows the existing manual-mirror
  convention (AGENTS.md "Agent boundaries"), it does not fix the underlying drift-check gap.

## Decisions

- **Key name: `layout.ocr.timeout`.** Matches the sibling precedent `layout.api.timeout`
  (`templates/_helpers/app/layout-api.tpl:199-202`, `dig "timeout" 120 $in`) rather than a novel
  name — the chart already has one `<block>.timeout` convention under `layout`, and `ocrTimeout`
  is the exact env key `ai-server`'s `ocr_tesseract.py:84` already reads
  (`int(env.get("ocrTimeout", 120))`). The new helper `groundx.layout.ocr.timeout` mirrors
  `groundx.layout.api.timeout`'s shape exactly (`dig "timeout" 120 $in`), so unset renders `120` —
  the same default `ai-server` already falls back to, making this additive with zero rendering
  change for any values file that doesn't set it (confirmed in `contract.md`; no compatibility
  mechanism beyond "unset = old behavior" is needed because the value is a genuinely new,
  independently-defaulted field, not a change to an existing shape).
- **Schema: `type: integer`, `minimum: 1`, `maximum: 250`.** `ai-server`'s reader does an
  unguarded `int(env.get(...))` (`document/ocr_tesseract.py:84`) — the schema is the only guard
  against a non-positive or absurd value ever reaching it. A `minimum`+`maximum` pair on an
  integer already exists elsewhere in this schema (e.g. the port range at
  `values.schema.json:1305-1307`, `minimum: 1, maximum: 65535`), so this is a followed convention,
  not a novel schema shape.
- **250 ceiling arithmetic.** Per FRA-115's final review (round 5 dropped the redundant
  `image_to_string` pass): the OCR budget for one page is at most 2 Tesseract attempts
  (full-resolution, then one 0.75x downscaled retry). Worst case ≈ 2 × `ocrTimeout`. The layout
  Celery workers run under `TaskTO=600` (a **soft** limit; `ai-server`'s `celery_process.py:89`
  has no corresponding hard limit) for the whole per-page task, of which OCR is only part. At the
  ceiling, 2 × 250s = 500s, leaving ~100s margin for the surrounding non-OCR work (image load,
  downscale, upload) in the same task. This chart does not expose `TaskTO` and this change does
  not add that exposure — the ceiling is the only enforcement mechanism available here, and it is
  a static, documented bound, not a runtime check.
- **Value takes effect only on the Tesseract path.** `layout.ocr.type=google` routes to a
  different OCR backend that does not consult this timeout; this is a fact about `ai-server`'s
  code, not something this chart's render branches on. The chart renders `ocrTimeout`
  unconditionally (exactly like it already renders `ocrProject`/`ocrType` unconditionally,
  regardless of which OCR backend is selected) — branching the chart's render on `ocrType` would
  be a `src/groundx`-side assumption about `ai-server`'s internals this repo has no way to keep in
  sync, and the unconditional render is what keeps this additive.
- **Snapshot regeneration method: "Apply only regenerated lines" (human-approved at the rest
  gate, 2026-09-25) — regenerate in a scratch copy, machine-extract only the changed lines, patch
  those lines into the committed snapshots. No `-u` run ever touches a committed snapshot file,
  and no value is typed by hand.** This repo's `AGENTS.md` "Agent boundaries" section instructs
  hand-patching `.snap` files instead of `-u`, because the installed `helm-unittest` plugin (v1.1.2)
  has previously dropped or reordered snapshot labels on regeneration (FRA-145, tracked further as
  GX-59). This revise pass re-tested that premise directly — pinned v3.19.0, OCR fixture present,
  both scoped to `resources_test.yaml.snap` alone and combined across all four affected snapshot
  files — and found `helm unittest -u` reproduces the same corruption every time when run against
  the committed snapshots in place: dropped `'disabled: …'` labels, re-quoted/renamed keys,
  reordered secret refs, injected unrelated `admin`/`apiKey` content — even under the pinned
  binary, not only the ambient one. The same pass confirmed a **plain** (`-u`-less) `helm unittest`
  run against the committed snapshots, with the OCR fixture present, is byte-exact-safe (it compares
  against the committed golden file rather than rewriting it). Given both facts, task 3.1 follows
  this method:
  1. Run `helm unittest -u` only against a **scratch copy** of `src/groundx` — never against the
     worktree's committed snapshot files directly. The corruption is harmless there because the
     scratch copy is discarded after use.
  2. Use a small throwaway script (not committed) to extract, from that scratch run's output, only
     the new `ocrTimeout=<int>,` line(s) and the new `config-hash` annotation values for the four
     affected snapshots (`resources`/`api`/`celery`/`inference`).
  3. Apply only those line-level changes to the committed snapshot files, so every other byte in
     each file stays identical to its base-branch content — no value is typed by hand.
  4. Verify the result with a plain (`-u`-less) `helm unittest src/groundx` (pinned binary, OCR
     fixture present) exiting 0, `verify-helm-snapshots.py`, and `.build/bin/validate-helm.sh`; the
     snapshot diff against the base branch must touch only `ocrTimeout`/`config-hash` lines.
  5. Commit the four snapshot files together in their own commit, separate from the
     schema/helper/template commit; the PR body states this method and cites GX-59.

  Hand-patching by typing a value directly into a committed snapshot is **not** the default and is
  not used by this method — every value that lands in a committed snapshot is machine-extracted
  from the scratch `-u` output in step 2, never hand-typed. The diff-only-safe-lines check (task
  3.1's `check:`) still verifies the *result* against the base branch, so the committed snapshots
  are held to the same bar regardless of which extraction script produced the patch.
- **Every layout pod restarts once on first upgrade.** All 7 layout Celery workers
  (`correct`/`map`/`ocr`/`process`/`save`, plus `api`/`inference`) read the same
  `layout-config-py-map` Secret and share its `config-hash` restart annotation. Adding
  `ocrTimeout` to that Secret's rendered content changes the hash once, so every layout pod
  restarts on the first upgrade that includes this change — even for deployments that never set
  `layout.ocr.timeout` (the rendered default line still changes the Secret's content from "no
  `ocrTimeout` key" to `ocrTimeout=120`). This is a one-time rollout event, not a recurring one;
  call it out in the PR/release notes rather than gating on it here.
- **Image precondition.** The value has no effect until the deployed `layout-process`/`layout-ocr`
  image is built from an `ai-server` commit at or after the FRA-115 merge (tagged into the
  `0.2.7` image line, 2026-08-18) — `helm/Chart.yaml` on `0.2.7` still declares `appVersion:
  0.2.6` today, so an operator upgrading only the chart (not the image) would set a value that
  is silently ignored by an older image reading no such env key at all. This is a deployment-time
  fact for the PR/release notes, not something the chart can detect or gate on.
- **No ADR.** This is a bounded, reversible chart-values addition that follows an existing sibling
  pattern (`layout.api.timeout`) with no new subsystem, contract shape, or hard-to-reverse
  structural choice — it does not meet the bar for an architecturally significant decision.
- **Cross-service shape:** see `contract.md` for the full producer/consumer shapes (rendered
  `config.py` key, schema field, harness doc touchpoint); not duplicated here.

## Risks / Trade-offs

- **Config-hash restart is unconditional.** Every layout pod restarts once on upgrade regardless
  of whether an operator uses the new value — accepted (see Decisions); it is a one-time,
  documented event, not a recurring cost, and avoiding it would mean not rendering the default at
  all, which would make an unset value silently diverge from `ai-server`'s own default over time
  if that default ever changes.
- **`helm/` mirror still has no drift-check tooling.** This change is mirrored by hand into
  `helm/`, same as every other chart change today; the underlying gap (no regen script, no CI
  drift check between `src/groundx` and `helm/`) is out of scope for this change and remains a
  known repo-wide risk (`AGENTS.md` "Repo-specific gotchas").
- **The 250 ceiling is a documented bound, not an enforced one.** Nothing in this chart or
  `ai-server` measures actual elapsed OCR time against the Celery soft limit at runtime; a future
  change to the retry-attempt count or to `TaskTO` itself would silently invalidate this
  arithmetic. Re-deriving the ceiling is out of scope here (it belongs with whichever change
  alters that budget).
- **The ambient (unpinned) local `helm` is unsafe for this repo's snapshot suite, confirmed
  directly during this authoring pass.** Running `helm unittest -f tests/resources_test.yaml .`
  under the ambient `helm v4.2.2` (not the repo's pinned `v3.19.0`) rewrote
  `tests/__snapshot__/resources_test.yaml.snap` — dropping the `'disabled: resources':` snapshot
  label, reordering/re-quoting unrelated keys, and injecting unrelated content (`admin`/`apiKey`
  fields) — on a plain run, with **no** `-u` flag. This is a stronger version of the drift
  AGENTS.md already documents for `-u` specifically; it means task 3's snapshot regeneration (and
  any exploratory `helm unittest` run against this suite) must use the pinned `v3.19.0` binary
  (`GX_ON_PREM_HELM` or a scratch binary) and never the ambient one, and any accidental snapshot
  file change from an unpinned run must be reverted (`git checkout --
  tests/__snapshot__/resources_test.yaml.snap`) before it is inspected for the intended diff.
