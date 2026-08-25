## Goals / Non-Goals

**Goals:**

- Make `celery.yaml`'s three `$hasOCR` guard sites render valid YAML when
  Google OCR is configured, in both `src/groundx/templates/app/celery.yaml`
  and its manual mirror `helm/templates/app/celery.yaml`.
- Leave the default/Tesseract (`$hasOCR` false) rendered output exactly as
  it is today.

**Non-Goals:**

- No `values.yaml`, `values.schema.json`, `_helpers/*.tpl`, or `Chart.yaml`
  change, and no version bump — the fix is confined to the three guard
  sites' opening tag.
- No new helm-unittest fixture committed to the chart (a Google-OCR render
  needs a packaged credentials file at render time; this design uses an
  ad hoc, non-committed throwaway file for verification instead of adding
  a permanent fixture — see Decisions).
- No harness/documentation change (GX-4/GX-10 track the harness-doc gap
  separately; out of scope here per the source-of-truth pack).

## Decisions

**Invariant (this is a same-shaped edit at 3 sites across 2 files, so it is
treated as a mechanical sweep):** the edit must keep the default/Tesseract
rendered output byte-for-byte unchanged, and must make the Google-OCR
rendered output parse as valid YAML — never the reverse (an edit that
"looks right" at all three sites but still leaves either branch's output
wrong is not the fix).

- **The edit.** At all three sites in `src/groundx/templates/app/celery.yaml`
  (verified at lines 66, 174, 189 via `grep -n hasOCR`) and the identical
  three sites in `helm/templates/app/celery.yaml`, change
  `{{- if eq $hasOCR "true" -}}` to `{{- if eq $hasOCR "true" }}` — drop the
  trailing `-` on the **opening** guard tag only. The paired `{{- end }}`
  tags are already `}}` (no trailing dash) and are left untouched. Read in
  context (`src/groundx/templates/app/celery.yaml:64-68`,
  `:172-176`, `:187-191`), each site guards exactly one mapping key
  (`ocr-credentials-hash: …`, a `credentials-volume` volume mount, and a
  `credentials-volume` volume) that must stay on its own line; right-trimming
  the newline after the opening `if` concatenates that key onto the
  preceding line, producing two mapping keys on one line — invalid YAML.
  Because the guarded content is skipped entirely when `$hasOCR` is false,
  the opening tag's right-trim has no effect on the false branch (the
  `{{- end }}`'s own left-trim already absorbs the preceding newline when
  the block is skipped) — dropping it changes only the true-branch output.
- **Why `helm/` too.** `helm/` is a manual mirror of `src/groundx/`, not
  independently maintained (repo `AGENTS.md`); a fix landing only in
  `src/groundx/` would leave the next published chart (built from `helm/`
  via `src/build.sh`) carrying the same bug. Both files get the identical
  three-site edit in this change.
- **Verification is a real render, not a snapshot diff, because no
  existing test exercises the true branch.** Confirmed by grep across
  `src/groundx/values.yaml`, every file under `src/groundx/values/`, and
  every fixture under `src/groundx/tests/files/`: none sets
  `layout.ocr.type: google` or `layout.ocr.credentials`, so `$hasOCR` is
  `false` in every values combination the chart ships or tests with today.
  Confirmed empirically: `helm unittest src/groundx` on the unchanged code
  passes 202/202 tests, 815/815 snapshots (run 2026-08-25). Consequently a
  snapshot-only gate would stay green whether or not this bug exists, so
  the load-bearing check is a direct `helm template` render with
  `layout.ocr.type=google` — confirmed to fail today with the exact
  documented error (`error converting YAML to JSON: yaml: line 23: mapping
  values are not allowed in this context`, run against `src/groundx`; the
  identical failure was also reproduced against the `helm/` mirror,
  2026-08-25) and to succeed against the default/no-OCR values (`helm
  template gx src/groundx -n eyelevel` exits `0` unchanged).
  This design deliberately does **not** add a permanent Google-OCR fixture
  (a committed `files/ocr/credentials.json` plus a new `celery_test.yaml`
  case) — the chart's `.Files.Glob`/`.Files.Get` call needs a real file on
  disk relative to chart root at render time, and committing one would add
  a packaged-chart artifact and a new golden snapshot for something the
  proposal scopes as template-only. The render check instead creates a
  throwaway `files/ocr/credentials.json`, runs `helm template`, and removes
  the file again (tasks.md's `check:` command does this in one line so
  nothing is left staged) — a `.helmignore`-independent, non-destructive
  local verification.
- **No ADR.** This is a two-character-per-site whitespace correction to a
  known bug with a verified, single-shaped fix; it is not an
  architecturally significant or hard-to-reverse decision, so no ADR is
  written for it.

## Risks / Trade-offs

- **Manual-mirror omission.** `helm/` has no regen script and no drift
  check against `src/groundx/` (a standing repo gap, not something this
  change fixes). The only mitigation available at this scope is applying
  the identical edit to both files in the same commit, which this change
  does.
- **Whitespace edits can still perturb an unrelated snapshot** if a guard
  site's surrounding indentation differs subtly between contexts. Mitigated
  by running the **full** `helm unittest src/groundx` suite (not just a
  targeted assertion) after the edit and comparing pass/fail and snapshot
  counts against the pre-fix baseline (202 tests / 815 snapshots) — any
  unexpected diff triggers `helm unittest -u src/groundx` review before
  committing a regenerated snapshot, per the repo's own AGENTS.md
  guidance for that file class.

## Migration Plan

No rollout, canary, secret, or stateful-resource change. Every environment
re-renders `celery.yaml` on its next `helm template`/`helm upgrade`; the
output is unchanged unless Google OCR is enabled, in which case rendering
now succeeds instead of failing. Rollback is reverting the two-file edit;
no running deployment currently depends on the broken behavior, since no
environment can render with Google OCR enabled today.

## Open Questions

None.

## Amendments

- **2026-08-25 — round-2 review supersedes the "no committed fixture" Non-Goal.**
  The Non-Goals and Decisions above state this change deliberately does not add a
  permanent Google-OCR helm-unittest fixture, relying only on ad-hoc throwaway
  render checks. Code review (sdd-reviewer + cx-reviewer, corroborated) found that
  approach leaves the repaired `$hasOCR`-true branch unguarded by CI: `helm unittest`
  never sets `layout.ocr.credentials`, so a reintroduced `-}}` chomp would pass CI
  green. Round-2 review therefore **committed a permanent regression test** —
  `src/groundx/tests/celery_test.yaml` "google OCR enabled" case, driven by
  `src/groundx/tests/files/values.ocr-google.yaml` and the placeholder fixture
  `src/groundx/files/ocr/google-fixture-credentials.json` (`{}`) — verified to fail
  when the chomp is reintroduced. The `tasks.md` 1.1/1.2 render checks (throwaway
  file) remain as-is; the committed unittest case is the durable CI guard that
  supplements them.
- **2026-08-25 — accepted tradeoff (F3).** The `{}` fixture ships in the published
  chart: `.Files.Glob` (used to resolve `layout.ocr.credentials`) honors `.helmignore`,
  so the fixture cannot be both excluded from the package and usable by the test.
  It is inert (empty JSON, unreferenced by default values since `layout.ocr.credentials`
  defaults to `""`) and clearly named as a fixture; accepted as-is at the review gate.
- **2026-08-25 — correction.** The Decisions section states the published chart is
  "built from `helm/` via `src/build.sh`". That is inaccurate: `src/build.sh` runs
  `helm package` on **`src/groundx`** (not `helm/`) before publishing. The reason both
  `src/groundx` and `helm/` are edited is the manual-mirror convention, not that the
  package is built from `helm/`.
- **2026-08-25 — deferred follow-up (F5).** cx-reviewer surfaced (verified) a
  pre-existing gating divergence, newly reachable now that the `$hasOCR`-true path
  renders: `celery.yaml` gates the `credentials-volume`/mount/annotation on `$hasOCR`
  (credentials set), while `templates/resources/layout-ocr-credentials.yaml` gates the
  ConfigMap on `groundx.layout.ocr.create` (= `layout.ocr.enabled`, default true) **and**
  `$hasOCR`. With `layout.ocr.credentials` set **and** `layout.ocr.enabled: false`
  (schema-valid), `celery.yaml` mounts `<svc>-ocr-credentials-map` that is never created,
  so those pods fail to start. Out of scope for GX-11 (a whitespace-render fix); the
  primary Google-OCR-enabled path (`enabled` unset/true) is unaffected. Tracked as a
  follow-up to be filed.
