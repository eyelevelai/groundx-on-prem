## Goals / Non-Goals

The motivation, file inventory and approved decisions D3, D4 and D5 are in `proposal.md`; this document records how the chart half is built and why.

**Goals:**
- Every Go Deployment's `terminationGracePeriodSeconds` and every Go `config.yaml` block's `drainSeconds` come from one helper, so the default table and the `max 1 (sub grace 30)` formula each exist once.
- The five original queue services render as on `0.3.0` except `config-hash`; the other six services gain a default (150 or 900) and a `drainSeconds`.
- A `gracePeriod` override reaches only its own service, and an invalid one is rejected by the schema before any template renders.

**Non-Goals:**
- cashbot-go signal handling and its `drainSeconds` field on `config.Server` (separate change).
- Changing the 900-second queue default, the Celery and Python API settings, a `preStop` hook, or chart and app version bumps.
- A new `values.yaml` default key for any `gracePeriod`: a default key would become a second copy of the table.

## Decisions

### 1. One helper owns the default table and the formula

Invariant: a Go service's rendered `terminationGracePeriodSeconds` and `drainSeconds` come only from that service's own `gracePeriod` when set, otherwise from its single table entry, with the `− 30` floor applied in one place; they never take another service's value or a second copy of the table.

`templates/_helpers/app/golang.tpl` (beside `groundx.golang.services`) gains three helpers on the `groundx.celeryWorker.defaultGrace` / `gracePeriod` / `stopWaitSecs` pattern: `groundx.golang.defaultGrace` (the table: 900 for `preProcess`, `process`, `queue`, `summaryClient`, `upload`, `largeFileDeliver`, `postProcess`; 150 for `groundx`, `layoutWebhook`, `fileAccess`, `metrics`), `groundx.golang.gracePeriod` (`dict "key" <service> "replicas" <replicas dict>`, returns the dict's `gracePeriod` or the table entry) and `groundx.golang.drainSeconds` (same arguments, returns `max 1 (sub grace 30)`). An unknown key fails with `required` so a twelfth Go service cannot silently render no value. The helpers only read; they never `set` into `.Values`, which removes the five `set $in "gracePeriod" 900` writes that previously put the default into the shared values map.

Alternatives considered:
- Extending `groundx.celeryWorker.defaultGrace`. Rejected: the Celery table is keyed by Python worker names and defaults 300 for `summary.inference`; sharing it couples two unrelated services' defaults.
- A `gracePeriod` default in `values.yaml`. Rejected: it makes the default visible to the schema but copies the table, and `fileAccess` has no replicas block to hold one.

### 2. The replicas dict carries the override; each service gets a carrier only where it lacked one

`groundx`, `layoutWebhook` and `metrics` already pass their `replicas` dict through to `golang.yaml` / `metrics.yaml`, so the schema entry is all they need. `largeFileDeliver` and `postProcess` build `replicas` as `desired: N` only; their replicas helpers add `gracePeriod` from `.Values.<service>.replicas.gracePeriod` when it is set, and nothing when it is not. `fileAccess.replicas` is an integer, so a new `groundx.fileAccess.replicas` helper returns `desired` plus `gracePeriod` from the top-level `fileAccess.gracePeriod` when set; `fileAccess.settings` and `fileAccess.config` both read it. The five queue helpers lose their default-writing block and keep passing their own dict.

### 3. Pods and blocks read the same helper call

`templates/app/golang.yaml` renders `terminationGracePeriodSeconds` unconditionally from `groundx.golang.gracePeriod` with `key $entry` and `replicas $rp` (the loop key is the same service key the table uses), and `templates/app/metrics.yaml` does the same with `key "metrics"`. In `config-yaml.yaml` the five queue stanzas drop their `hasKey` guard and call `groundx.golang.drainSeconds`; `groundxServer`, `layoutWebhookServer` and `metricsServer` gain the line in the same place, and `groundx.fileAccess.config`, `groundx.largeFileDeliver.config` and `groundx.postProcess.config` gain it as the first key of their server block. Because the pod and its block pass the same service key and the same replicas dict, they cannot disagree.

### 4. The schema is the only validator

`gracePeriod` (`integer`, `minimum: 1`) is added to the `replicas` blocks of `groundx`, `layoutWebhook`, `metrics`, `largeFileDeliver` and `postProcess` and as top-level `fileAccess.gracePeriod`, in `values.schema.json`. `additionalProperties: false` stays on every block and `fileAccess.replicas` stays `integer`, so `fileAccess.replicas: {gracePeriod: …}` is still rejected. No template-side `fail` is added: Helm reports `minimum: got 0, want 1` with the property path before any template runs.

### 5. Compatibility and rollout

The `config.yaml` touchpoint is additive. The four request-serving blocks gain a key that cashbot-go's non-strict `yaml.v2` decoder ignores when its struct has no matching field (`repos/cashbot-go` `pkg/config/config.go:94`, no `SetStrict` in the package's non-test files at `9338e4c3e`); `largeFileDeliveryServer` and `postProcessFileServer` decode into `config.QueueServer`, which already has `DrainSeconds` (`pkg/config/types.go:314`). The contract shapes live in `contract.md`; the apply phase confirms them against the rendered config.

Rollout, in order:
1. Merge and release the chart on the `0.3.0` line. Every Go Deployment restarts once because `config-hash` changes; stateful resources are untouched and no manual operation, secret change or SQL is involved.
2. A cluster that keeps old cashbot-go images behaves as today for `groundx`, `layoutWebhook`, `metrics` and `fileAccess`; `largeFileDeliver` and `postProcess` start draining up to 870 seconds immediately on any image with queue-server drain (approved D4).
3. A new image on an old chart makes File Access exit with no wait (approved D3). Both facts go in `docs/upgrades.md`.
4. Rollback restores the previous chart; an operator who set a new `gracePeriod` removes it first, because the previous schema rejects the key.

### 6. Tests, snapshots and the mirror

Acceptance suites are new files, one per task group, so a filtered `helm unittest -f` run proves exactly one group and none rewrites a snapshot: `go_grace_groundx_test.yaml`, `go_grace_request_serving_test.yaml`, `go_grace_file_access_test.yaml` and `go_grace_queue_test.yaml`. The two `golang_test.yaml` cases asserting "renders no grace period" are replaced by the 150-second defaults. Existing snapshots are hand-edited from the failing diff, never regenerated with `-u`; the check that they only grew requires every removed snapshot line to be a `config-hash` line. `helm/` has no `tests/` tree, so D5's "both trees separately" reduces to `src/groundx/tests/` alone plus the byte-identical `templates/`, `values.yaml` and `values.schema.json` mirror that `.build/bin/verify-storage-contract.py:216` enforces.

## Amendments

### 2026-11-11 Snapshot production

Section 6 says the snapshots were hand-edited and never regenerated with `-u`. They were produced with `helm unittest -u` on a scratch copy of the chart only, and merged into the worktree entry by entry. Every line removed from a snapshot is a `config-hash` line. Accepted 2026-11-11 at the review gate.

### 2026-11-11 Task 4.2 wording superseded

tasks.md task 4.2 ("hand-patch every snapshot ... never with -u") is superseded by the snapshot-production amendment above. Snapshots were produced with `helm unittest -u` on a scratch copy only and merged entry by entry; removed lines are config-hash only.

### 2026-11-11 Scope of the `replicas.desired: 1` defaults

Before the review fix, only `metrics` rejected a bare `replicas.gracePeriod` override, because its schema requires `desired`. The `replicas.desired: 1` defaults added for `largeFileDeliver` and `postProcess` change nothing: their schemas do not require `desired` and their helpers already default it to 1. Their two bare-override tests pass with or without that default. The defaults are kept for symmetry. The fix commit's message overstates this.

### 2026-11-11 Deleted golang_test.yaml cases

Task 4.1 and the earlier design text describe two golang_test.yaml cases rewritten to equal-150. Those cases were deleted instead, as duplicates of go_grace_groundx_test.yaml and go_grace_request_serving_test.yaml.
