## Why

`src/groundx/tests/__snapshot__/celery_test.yaml.snap` re-renders non-deterministically on an
unmodified base (`GX-22`): two successive `helm unittest src/groundx` runs each leave the golden
file dirty. That snapshot suite is this repo's only CI gate on template changes
(`.github/workflows/helm-tests.yml`), so a non-deterministic golden can absorb a real regression
without failing.

**Amendment.** This proposal originally pursued a chart-helper `.Values`-aliasing deep-copy sweep
across 22 helpers. An apply-mode attempt at that fix could not reproduce the reported drift at all
— 15 repeat `helm unittest -u` regens on the CI-pinned Helm version were byte-identical — which
empirically falsifies the hypothesis. The actual root cause: the `helm-unittest` plugin is
installed **unpinned** (`helm plugin install` with no `--version`) at every install site, so it
resolves to whatever release the plugin's `main` branch currently names — today `v1.1.2`. That
release's snapshot cache (`pkg/unittest/snapshot/cache.go:159-181`) rewrites the entire `.snap`
file whenever a snapshot entry vanishes, but counts only *updated* entries as failures — so a
vanished empty-render label (`disabled: celery`) is silently dropped from the file while the run
still reports **PASS**, under `-u` (proven at every release from 2019 to an unreleased `main`
build). The CI/pre-push gate's own invocation (plain `helm unittest`, never `-u`) was separately
confirmed never exposed to this mechanism at any tested version — its write gate cannot be
tripped by a value-only mismatch, only a structural insert/vanish, which no run in this
investigation produced. Separately, this repo has
no `.gitattributes` line-ending pin, so a Windows checkout renders chart resources with CRLF
against the LF blobs the committed snapshot's `*-hash` annotations were computed from — harmless
churn, unrelated to the plugin defect, found investigating this ticket and worth closing at the
same time. Both earlier hypotheses (`.Values` aliasing; unsorted Go map-range order) are
empirically falsified: 0 of 284 observed snapshot mismatches touched a replicas/HPA or `secretRef`
value.

## What Changes

- **Add `.gitattributes`** (repo root) pinning chart source
  (`src/groundx/templates/**`, `helm/templates/**`, related YAML/JSON) to `eol=lf`. Checkout-policy
  only — zero index-content delta.
- **Pin the `helm-unittest` plugin version at a single source of truth**, asserted by
  `.build/bin/validate-helm.sh`: a pinned-version definition plus an assertion that the installed
  plugin matches it. Propagate the same pin to every install site
  (`.github/workflows/helm-tests.yml`, `docs/agents/repo-guide.md`, `ARCHITECTURE_NOTES.md`).
- **Add a snapshot-rewrite assertion to `.build/bin/validate-helm.sh`, placed immediately after
  each `helm unittest` invocation** — not at the end of the script, since `verify-helm-snapshots.py`
  already exits the script first on this failure class under `set -euo pipefail`, so an
  end-of-script check would never run.
- **Pin the plugin on the newest official release, `v1.1.2`.** The plan's chosen fork at the plan
  gate was option (a): freeze on the newest *older* release that still emits every required
  empty-render label. An empirical backward tag search (every tag from `v0.3.0` through an
  unreleased `main` build) found that option (a) **does not exist** — the label-drop is a
  structural property of the plugin's zero-manifest snapshot handling, present at every release,
  not a version-selection problem. A follow-on investigation found the actual CI/pre-push gate
  invocation (plain `helm unittest`, never `-u`) was never exposed to this defect at any tested
  version, so the newest release is pinned with no loss of protection and no snapshot
  regeneration required. See `design.md`'s Decisions for the full evidence.
- **Keep the already-landed guard tooling as-is.** `.build/bin/verify-helm-mirror.py` and
  `.build/bin/check-render-determinism.py` (committed at `e9d61bb` during the withdrawn approach)
  stay: mirror-equality blocking, repeat-render determinism warn-only with no flip condition in
  this change (it renders through the `helm` binary, not the `helm-unittest` plugin's own SDK, so
  it structurally cannot observe this defect class).
- **Withdrawn from scope:** the 22-helper `.Values`-aliasing sweep (real code smell by direct
  reading, proven irrelevant to every observed diff — needs its own Linear ticket, not yet filed);
  the unsorted-map-range hypothesis and any edit to `celery.yaml`'s range loops; flipping
  `check-render-determinism.py` to blocking.

No BREAKING changes: this is a test-tooling pin plus a line-ending policy fix. No chart template,
no `values.schema.json`, and (on the chosen fork) no snapshot content changes.

**Blast radius.** All environments render from the same chart and the same toolchain pin, so there
is no per-environment rollout risk to sequence. No stateful resource (db/cache/search/file) is read
or written by this change; scope is a new dotfile, the CI/local build-gate script, and doc/workflow
install-command references only. **Rollback:** revert the commit(s); the plugin-version and
snapshot-rewrite assertions are both new and additive, so a revert cannot leave a
broken-and-blocking gate behind. **Rollforward:** no data migration is involved; re-applying is a
plain re-pin.

**Environments / stateful impact:** dev/staging/prod all redeploy from the same source; no
environment-specific values file is targeted and none is expected to render differently from
another. No data or stateful-resource impact.

**Open design questions:** none. The plugin-pin mechanism, the chosen empty-label-preserving fork,
and the gate-assertion placement are fully specified in the accepted cross-service plan; no
`superpowers:brainstorming` needed.

## Capabilities

### New Capabilities
- `helm-toolchain-pinning`: the `helm-unittest` plugin version is pinned at a single source of
  truth and asserted by the build gate (`.build/bin/validate-helm.sh`); chart source checks out
  with consistent line endings on every platform (`.gitattributes`); the gate detects a
  `helm unittest`-driven snapshot rewrite at the point it happens.

### Modified Capabilities
(none — no existing spec's requirements change; the only existing capability,
`workspace-managed-data`, is unrelated to chart-helper rendering or the build gate.)

## Impact

- `.gitattributes` — new file, repo root; pins chart source to `eol=lf`.
- `.build/bin/validate-helm.sh` — pinned-version definition, plugin-version assertion, and a
  snapshot-rewrite assertion placed immediately after each `helm unittest` invocation.
- `.github/workflows/helm-tests.yml`, `docs/agents/repo-guide.md`, `ARCHITECTURE_NOTES.md` —
  plugin install commands updated to carry the pin.
- `scripts/githooks/groundx-on-prem/install.sh`, `NOTES.md` (meta-repo, human pass) — kept in sync
  with the same pin.
- No `src/groundx/templates/**` or `helm/templates/**` file is edited.
- `src/groundx/tests/__snapshot__/*.snap` — not touched; the newest-release pin requires no
  regeneration.
- Already-landed guard tooling (`.build/bin/verify-helm-mirror.py`,
  `.build/bin/check-render-determinism.py`, committed at `e9d61bb`) is unaffected by this change.

## Amendments

**2026-09-19.** The withdrawn 22-helper `.Values`-aliasing sweep named in "What Changes" above
("needs its own Linear ticket, not yet filed") is now tracked as **GX-58**. The original text is
left as written; this entry supersedes it in place. See `design.md`'s Amendments for the other
follow-up item filed from this change (GX-59, the `helm-unittest -u` empty-render label-drop
hazard), which this proposal did not separately name.
