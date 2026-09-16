## Why

`src/groundx/tests/__snapshot__/celery_test.yaml.snap` re-renders non-deterministically on an
unmodified base (`GX-22`): two successive `helm unittest src/groundx` runs each leave the golden
file dirty with differing `secretRef`/`disabled` entries. That snapshot suite is this repo's only
CI gate on template changes (`.github/workflows/helm-tests.yml`), so a non-deterministic golden can
absorb a real regression without failing, and every legitimate regen produces spurious diff noise.
The reported drift is reproduced but not yet independently re-confirmed, and its root cause is an
unconfirmed hypothesis — this proposal fixes the confirmed mechanism, not the hypothesis.

## What Changes

- **Reproduce and attribute before touching code.** Reproduce the two-run drift on a clean base,
  record the exact diverging lines, and determine which template/helper actually emits each one —
  the documented `secretRef`/`disabled` symptom goes through a `fromYaml`-copied path
  (`celery.yaml` → `groundx.secrets`) that does not alias `.Values`, so attribution must confirm
  which of the celery suite's 8 candidate helpers (of 22 total `.Values`-aliasing helpers repo-wide)
  is actually responsible before any fix is written.
- **Fix and prove on exactly one helper first.** Deep-copy the attribution-selected helper's
  `.Values`-derived submap before it is mutated (in place `dig`-then-`set` is the defect shape),
  mirror that one file into `helm/`, and re-run the two-run reproduction. Proceed to the wider sweep
  only once the attributed drift is confirmed to disappear (a single-helper fix against an
  8-helper-rendering suite is expected to only partially clean the snapshot — that is the pass
  signal, not total drift elimination).
- **Sweep the remaining helpers, once proven.** Apply the same deep-copy treatment to the other 21
  `.Values`-aliasing replica/HPA helpers (one consistent treatment, not per-file variants); mirror
  each into `helm/`. The 6 already-safe `fromYaml`-based helpers are explicitly out of scope.
- **Regenerate the snapshot(s) under mandatory human review.** Never a blind `helm unittest -u`
  commit — every changed entry is reviewed to confirm it is a leaked-value-to-own-default
  correction, not a resource appearing/disappearing or a body moving to the wrong test label.
- **Harden the gate, with two different landing rules.** Add to `.build/bin/validate-helm.sh`: (a)
  an unconditional, immediately-blocking `helm/` vs `src/groundx/templates` mirror-equality check
  (no equality check exists today — a partially-mirrored fix would otherwise ship as silent drift),
  and (b) a repeat-render determinism check that lands **warn-only** if the fix is not yet confirmed
  clean, flipping to **blocking** once Stage 1+2 land and a two-run recipe is observed clean — the
  warning text itself must say so (the script has no comment channel available for this).
- **Escalate rather than widen, if attribution says otherwise.** If the drift attributes entirely to
  the `$scr`/`groundx.secrets` path (not `.Values` aliasing), no single-helper experiment can
  confirm or refute the aliasing hypothesis — stop, escalate with the attribution evidence, and treat
  the aliasing defect (real, but unproven as this ticket's cause) as a separate change.

No BREAKING changes: this fixes rendering determinism and hardens the build gate; it does not change
`values.schema.json` or any values contract.

**Blast radius.** All three deploy targets (dev/staging/prod, plus eks/aks/gke/openshift/minikube)
render from the same chart version and the same `helm/` mirror, so there is no per-environment
rollout risk to sequence — a genuine semantic delta (an HPA/replica default actually changing for
some values profile) would show up identically everywhere and is the documented trigger to escalate
rather than proceed, not something to canary. No stateful resource (db/cache/search/file) is read or
written by this change; scope is chart templates, generated snapshot fixtures, and the CI gate
script only. **Rollback:** revert the commit(s); the mirror-equality check and the
flipped-to-blocking determinism check are only made blocking after Stage 1+2 are verified, so an
early-stage revert never leaves a broken-and-blocking gate behind. **Rollforward:** no data
migration is involved; re-applying is a plain redeploy from the regenerated chart.

**Environments / stateful impact:** dev/staging/prod all redeploy from the same source; no
environment-specific values file is targeted and none is expected to render differently from
another. No data or stateful-resource impact.

**Open design questions:** none. Stage 0's attribute-before-fix decision tree, the 22-helper scope,
and the two gate checks' differing landing rules are fully specified in the accepted cross-service
plan; no `superpowers:brainstorming` needed.

## Capabilities

### New Capabilities
- `helm-chart-render-determinism`: the chart's `.Values`-aliasing replica/HPA helpers render
  identically across repeated `helm unittest` invocations (no shared-map mutation leaking between
  test cases sharing a helper), and the build gate (`.build/bin/validate-helm.sh`) machine-enforces
  both `helm/`/`src` mirror equality and, once proven clean, repeat-render determinism.

### Modified Capabilities
(none — no existing spec's requirements change; the only existing capability,
`workspace-managed-data`, is unrelated to chart-helper rendering or the build gate.)

## Impact

- `src/groundx/templates/_helpers/app/layout-ocr.tpl` — the Stage 0 default proof-gate helper
  (confirmed `.Values` alias at `:113`); fixed first, alone.
- `src/groundx/templates/_helpers/app/*.tpl` — the remaining 21 `.Values`-aliasing replica/HPA
  helpers (22 total; full list in the accepted cross-service plan), fixed only if Stage 0 confirms
  the mechanism.
- `src/groundx/templates/app/celery.yaml`, `_helpers/main.tpl`, `_helpers/app/celery.tpl` —
  read for attribution (the `$scr`/`groundx.secrets` path); edited only if attribution implicates
  them, which is not expected.
- `src/groundx/tests/__snapshot__/*.snap` — regenerated under human review (celery suite at
  minimum; any other suite the same leak touches).
- `.build/bin/validate-helm.sh` — two checks added: mirror-equality (blocking immediately) and
  repeat-render determinism (warn-only until proven, then blocking).
- `helm/templates/...` — mirrored copy of every `src/groundx/templates/` edit (existing repo
  convention; no regen script exists, so this stays a manual, now machine-checked, sync).
- `.github/workflows/helm-tests.yml` — touched only if a check cannot live in the script; not
  expected, since the script is already CI's and the local pre-push gate's single entrypoint.
