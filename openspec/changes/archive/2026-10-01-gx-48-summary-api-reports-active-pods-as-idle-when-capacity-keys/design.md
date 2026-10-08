## Goals / Non-Goals

**Goals:**
- Keep the autoscaler's `summary-api` throughput usage correct once ai-server#66 publishes one capacity
  record per gunicorn process, by giving cashbot-go a per-process `tokensPerMinute` for that service.
- Change nothing for `summary.api.workers: 1`.

**Non-Goals:**
- The `metrics.throughput` `summary-api` entry, the default helpers, the HPA threshold, other services,
  or the values schema. See `proposal.md`.

## Decisions

- **Fix site.** The `summary-api` entry of `metrics.inference` in `config-yaml.yaml` reads `$sac`
  (`groundx.summary.api.threshold`). Add two local variables next to `$sac` and render the derived value
  in that entry only: `$saw := max 1 (workers | int)` and
  `$sacw := max 1 (div ($sac | int) $saw)`. The `if ne $sac "0"` guards (the `or (...)` header and the
  entry guard) keep reading `$sac`, so the entry is still omitted when the threshold is `0`.
  `$sat` and the `throughput:` list are not touched.
- **Which entry is "per pod".** The ticket text calls the unchanged entry the `api:` metrics entry; in the
  rendered config the `$sat` value lives under `metrics.throughput` (the `api:` list carries only
  `threshold` entries and has no `summary-api` row). The spec and test therefore assert on
  `metrics.throughput`.
- **Why division in the template, not a new helper or value.** One call site, one arithmetic expression:
  a new `groundx.summary.api.threshold.perProcess` helper or values key would add a public surface for a
  single use. Reuse `groundx.summary.api.workers`, which already feeds the gunicorn config
  (`summary-gunicorn-conf-py.yaml`), so the divisor is the same number that sets the process count.
- **Why the floors.** `max 1` on `workers` removes a division-by-zero render failure for a nonsensical
  `workers: 0`; `max 1` on the result keeps cashbot-go from reading `0` as "no metric"
  (`metrics.go:364`). Today the schema does not let a user set `threshold` (only `desired`/`max`/`min` are
  accepted under `summary.api.replicas`), so `threshold = 2400 * threads * workers` and the result is
  `2400 * threads`; the second floor is defensive and is not separately testable through the schema.
- **Integer division.** `threshold` is `2400 * threads * workers`, so with defaults the division is exact;
  integer division only matters if the default helpers change later.
- **Alternatives rejected.**
  - *Divide in cashbot-go* (`through / (tpm * period * cnt)` made aware of workers): cashbot-go cannot know
    the chart's worker count and the human approved the chart-side fix.
  - *Change `groundx.summary.api.threshold` itself*: it also feeds the HPA threshold and the `api` list
    semantics; out of scope and wider blast radius.
  - *Leave per-pod and have ai-server keep one record per pod*: contradicts ai-server#66's per-process ids,
    which fix the multiple-workers-overwrite-each-other defect.
- **Coupling and rollout.** See `proposal.md` Impact: correct only with ai-server#66; release together.
  With `workers: 1` the order does not matter.
- **Snapshot churn.** The shared fixture `tests/files/values.metadata.yaml` sets summary `workers: 2`, so
  `metadata: resources` (`resources_test.yaml`) and `metadata: golang` (`golang_test.yaml`,
  `metrics_test.yaml`) change: the `myapp-api` inference value halves in the first, and only the
  config-hash changes in the other two. Regenerating exactly these is expected; any other snapshot
  changing means the default path moved and is a defect. Snapshots must be regenerated through the
  repo gate's fixture setup, never with a bare `helm unittest` (a missing OCR fixture makes it rewrite
  unrelated snapshots).
- **Mirror.** `helm/` has no regen script or drift check; the two `config-yaml.yaml` files are
  byte-identical today and are kept so by hand, verified by `diff` in tasks.
- **No ADR.** One arithmetic expression at one call site with a documented coupling; the decision record
  is this file plus the proposal.
