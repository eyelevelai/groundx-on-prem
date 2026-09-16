## Decisions

**Invariant (mechanical sweep — the 22-helper treatment).** A submap a helper obtains from
`.Values` via `dig` and then defaults into with `set` must never be the same map object `.Values`
holds; only a value that has been round-tripped through serialization (`toYaml | fromYaml`) may be
passed to `set`. This guarantees two renders of the same input reach every `set` call with two
independently-allocated maps, so one test case's defaulting can never surface in a sibling case's
output.

**Invariant (gate — mirror equality).** Every file under `src/groundx/templates` must have a
byte-identical counterpart at the same relative path under `helm/templates`, and vice versa, before
either surface is trusted as a deploy artifact. A rename, edit, or add on one side that is not
mirrored on the other is a broken build, not accepted drift.

**Invariant (gate — repeat-render determinism).** Two renders of the chart from the same `.Values`
input must be byte-identical. A diff is a defect in the templates, never expected nondeterminism to
be absorbed by re-goldening the snapshot. Until this is proven true across the sweep, the check
reports without blocking, so it cannot turn every push and every CI run red against a baseline that
is not yet fixed.

## Grounding finding — sharpening Stage 0's attribution, not overriding it

Reading `celery.yaml`, `_helpers/main.tpl`, and `_helpers/app/extract-agent.tpl` during design
authorship surfaces a second, more parsimonious candidate for the *reported* symptom than the
ticket's `.Values`-aliasing hypothesis, and it sits squarely in the plan's own "$scr /
`groundx.secrets` path" branch:

- `celery.yaml:29` builds `$scr` from `get $svcData "secrets" | default dict`. For `extract.agent`
  (`extract-agent.tpl:330-345,362-391`), that `"secrets"` key is a **freshly constructed** dict
  literal (1–2 keys, not dug from `.Values`) — not aliased, so a deep-copy fix would change nothing
  here.
- `celery.yaml:31-35` then merges `$globalSecrets` (also freshly built each call) into `$scr` with a
  manual `range $k, $v := $globalSecrets`, and `celery.yaml:135` renders `envFrom` with
  `range $kk, $vv := $scr` — **iterating a Go map directly, not through `toYaml`** (which marshals
  through `encoding/json` and is therefore key-sorted). Go's map iteration order is randomized per
  invocation by design, so a `$scr` with ≥2 keys emits its `secretRef` entries in a different order
  on every render — independent of any `.Values`-aliasing helper. The same shape recurs at
  `celery.yaml:129` (`range $envName, $envValue := $env`) and `:81` (`range $j, $inm := $ips`).
- This matches the reported cases exactly: `extract: celery` and `extract.oai: celery` set
  `cluster.secrets: [eyelevel-secret-credentials]` (`values/extract/values.yaml`,
  `values/extract/values.oai.yaml`); `extract.ingest: celery` sets `extract.agent.existingSecret` +
  `secretName` (`tests/files/values.extract.ingest.yaml`) — both give `$scr` ≥2 keys. The default
  case (`values.yaml`, no `cluster.secrets`) has an empty `$scr` and renders no `envFrom` block at
  all, which is consistent with it *not* appearing in the reported drifting list.

This is exactly the plan's already-anticipated asymmetric branch, sharpened with a concrete emitter
candidate — it does not replace Stage 0's empirical proof. **Stage 0 must still reproduce and
confirm before any fix is written**; this note only tells the implementer where to look first when
reading the recorded diff at Stage 0 step 2, alongside the `.Values`-aliasing candidate. If Stage 0
confirms the `$scr`/`$env`/`$ips` unsorted-range path (rather than `.Values` aliasing) as the
emitter, the plan's own rule applies without modification: **skip the single-helper experiment,
escalate with the recorded evidence, and treat both defects as separate** — the 22-helper aliasing
defect (real, per direct code reading of `layout-ocr.tpl`/`extract-agent.tpl`'s replicas helpers)
remains a genuine but distinct hardening item, not this ticket's confirmed cause.

## Fix mechanism (used only if Stage 0 confirms `.Values` aliasing)

Each of the 22 helpers builds its replicas/HPA submap the same way:
`$c := dig "<key>" dict $b` (or the innermost `dig "replicas" dict $c`) returns the actual nested
map value held inside `.Values` — Go maps are reference types, so `dig` never copies. The helper
then defaults missing fields onto that same map with `set`.

The fix is the smallest change that breaks the aliasing: pipe the `dig` result for the submap that
gets `set` through `toYaml | fromYaml` before any `set` call, e.g. in `layout-ocr.tpl:115`:

```
{{- $in := dig "replicas" dict $c | toYaml | fromYaml -}}
```

This is the same idiom the six already-safe `workspace-*.tpl` helpers use (`include ... | fromYaml`)
and the same idiom `celery.yaml:7` already uses for `$svcData` — an established, proven pattern in
this codebase, not a new dependency or a new shared helper function. One line changes per file;
"one consistent treatment," not 21 bespoke patches, per the plan.

## Tooling: two small, testable checkers (Guard change class)

Both the mirror-equality and repeat-render-determinism checks are guards (AGENTS.md "Guard change
class"), so each lives in its own sourceable, directly-testable file — following this repo's
existing convention (`.build/bin/verify-*.py` + `.build/tests/test_*.py`, e.g.
`verify-workspace-chart.py`) rather than embedding logic inline in `validate-helm.sh` or inventing a
new bash test harness:

- **`.build/bin/verify-helm-mirror.py`** — walks `src/groundx/templates` and `helm/templates`,
  reports any path present on only one side and any path whose content differs. Fails closed (a
  read error is a failure, not a silent pass). Called unconditionally and always blocking from
  `validate-helm.sh` — no landing-rule flag, since the plan and the confirmed current state (`diff
  -rq src/groundx/templates helm/templates` exits 0 today) both say it is safe to block from day one.
- **`.build/bin/check-render-determinism.py`** — renders a chart with `helm template` twice from
  identical `-f` values files (via `subprocess`, using `helm` off `PATH`, matching the existing
  `verify-workspace-chart.py` convention — no new env-var resolution is introduced; the ticket's
  `GX_ON_PREM_HELM` mention is an operator's local pin, not a code path anywhere in this repo today)
  and diffs the two renders. Two modes select the landing rule: `--warn-only` (print the diff plus
  the required "this is warn-only until GX-22 is confirmed fixed" message, exit 0) and the default
  blocking mode (exit 1 on any diff). An optional `--focus <regex>` narrows the pass/fail decision to
  diff lines matching the pattern — used by Stage 0's single-helper experiment to assert only the
  attributed field stabilized, without requiring the whole 8-helper-rendering suite to go clean in
  one step (the plan's documented partial-improvement pass criterion). Stage 3 wires it with no
  `--focus` (whole-render equality) and starts it with `--warn-only`; flipping to blocking after
  Stage 1+2 land is a one-line removal of that flag, never a rewrite.

Both fixtures ship in the same commit as each script (Guard change class (c)): a known-bad input
(differing/missing mirror file; a fake `helm` on `PATH` that returns different stdout each call) the
check must reject, and a legitimate case (identical mirror; a fake `helm` returning identical
output) it must not block. The fake-`helm`-on-`PATH` fixture mirrors this workspace's existing
pattern for testing a wrapper around an external binary without needing the real one
(`second-opinion.py`'s fake `codex`, `integration-backstop.py`'s fake `docker`/`go`).

## Rollout

All three deploy targets render from the same chart version and the same `helm/` mirror (see
proposal.md's blast-radius note) — nothing here is environment-specific, so there is no
canary/stage ordering to sequence. Landing order inside this change: (1) mirror-equality check
(blocking immediately — independent of the rest), (2) Stage 0 single-helper proof, (3) conditionally
Stage 1's 21-helper sweep, (4) Stage 2's human-reviewed snapshot regen, (5) the determinism check
starts warn-only and is flipped to blocking only once (3)+(4) land and a two-run render is observed
clean. A revert at any point before step 5's flip never leaves a blocking-and-broken gate behind.

## Open item carried into tasks.md

Per AGENTS.md "no-comment rule": the warn-only check's flip condition is recorded in the check's own
printed warning message (source of truth at runtime) and restated as an open item in tasks.md — never
as a `#` comment in `validate-helm.sh` or the Python checker.
