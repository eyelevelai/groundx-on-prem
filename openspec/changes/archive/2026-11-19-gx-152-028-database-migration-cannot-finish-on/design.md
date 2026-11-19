# Design: GX-152 configurable migration Job limits and a GitOps opt-in

The motivation and blast radius are in `proposal.md`. This document records how the chart change is built and tested.

## Goals / Non-Goals

**Goals:**
- Operators can set the migration Job's deadline and retry count. The defaults are 3600 s and 2 retries, and the schema rejects a deadline below 1 and a negative retry count.
- With an off-by-default value, the migration Secret and Job render without `.Release.IsUpgrade`, so Argo CD runs them as PreSync hooks.
- `docs/agents/database-upgrades.md` tells operators how to size the deadline and Helm's `--timeout`, what to do after a timeout, and what the opt-in needs.

**Non-Goals:**
- Changes to the GroundX image, its start-up migration, probes or the migration lock. Resuming a retried history build ships in cashbot-go under the same ticket.
- New hook annotations, Argo CD-specific annotations or a different delete policy.
- Changes to customer Argo CD or deployment repositories or their values, or `Chart.yaml`.
- groundx-studio-harness documentation, which is a separate change that waits for a published chart.

## Decisions

**Invariant (the gate changes in `.build/bin/validate-helm.sh`):** the gate passes only if both chart copies render the migration Job with exactly the configured or default deadline and retry count, reject an out-of-range limit through that key's own `minimum` rule rather than as an unknown key, and render the migration hooks without an upgrade flag only when the opt-in is on and a Go workload is enabled.

### 1. Values and how the template reads them

- New block in both `values.yaml` files, under `groundx`, after `disruptionBudget`:

  ```yaml
    migration:
      activeDeadlineSeconds: 3600
      backoffLimit: 2
      gitOps: false
  ```

- `templates/app/schema-migration.yaml` reads the block once, before the existing gate line, and uses `dig` with the same defaults:

  ```gotemplate
  {{- $migration := dig "migration" dict (.Values.groundx | default dict) -}}
  {{- if and (or .Release.IsUpgrade (dig "gitOps" false $migration)) (gt (len $svcs) 0) -}}
  ...
    backoffLimit: {{ dig "backoffLimit" 2 $migration }}
    activeDeadlineSeconds: {{ dig "activeDeadlineSeconds" 3600 $migration }}
  ```

- `dig` returns a key's value whenever the key exists, so an explicit `backoffLimit: 0` renders as 0. `| default 2` was rejected because Sprig's `default` treats 0 as empty and would render 2. On a scratch copy, a template using `| default 2` was caught by both the new `golang_test.yaml` case and the new gate assertion (2026-11-18).
- The `dig` defaults match the `values.yaml` defaults.
- No comment is added to `values.yaml`. The upgrade guide describes the keys.

### 2. The opt-in only widens the existing gate

The gate becomes `(IsUpgrade or gitOps) and at least one Go workload`. The Secret and Job bodies, names, hook annotations (`pre-upgrade`, weights `-10` and `-5`) and delete policy `before-hook-creation,hook-succeeded` are unchanged.

Alternatives rejected:
- Always rendering the hooks: an Argo CD first sync with the bundled MySQL would then run a PreSync Job before the database exists.
- Adding `argocd.argoproj.io/hook` annotations: Argo CD already maps Helm `pre-upgrade` to PreSync and `hook-weight` to sync wave ([Argo CD Helm hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/#helm-hooks)). Changing annotations is outside the approved plan.
- Detecting Argo CD from `.Release` or `.Capabilities`: `helm template` exposes no reliable signal for it.

Helm ignores the opt-in. Helm runs `pre-upgrade` hooks only during an upgrade, where `.Release.IsUpgrade` already renders them, and `helm install` does not run them.

Whether Argo CD keeps the hook Secret while a retry pod starts, and whether it runs the Job on every sync, are checked by the manual minikube Argo CD run (task 5.1). If the Secret is deleted before a retry pod starts, the fix changes annotations or delete policy, which needs the plan approved again.

### 3. Schema

Both `values.schema.json` files gain this property under `groundx.properties`:

```json
"migration": {
  "type": "object",
  "properties": {
    "activeDeadlineSeconds": { "type": "integer", "minimum": 1 },
    "backoffLimit": { "type": "integer", "minimum": 0 },
    "gitOps": { "type": "boolean" }
  },
  "additionalProperties": false
}
```

The shape follows `replicas.gracePeriod` (`"type": "integer", "minimum": 1`). Helm v3.19.0 reports these errors as `at '/groundx/migration/activeDeadlineSeconds': minimum: got 0, want 1` and `at '/groundx/migration/backoffLimit': minimum: got -1, want 0`, observed on a scratch chart on 2026-11-18. The base chart rejects every `groundx.migration` key with `at '/groundx': additional properties 'migration' not allowed`. For that reason the gate matches the full `minimum` text and pairs each rejection with a valid 7200/0 render.

### 4. Both chart copies change together

The template, `values.yaml` and `values.schema.json` are edited in `src/groundx` and copied byte-for-byte to `helm/`. `verify_mirrors()` (`.build/bin/verify-storage-contract.py:144-155`) and the `cmp` in `validate-helm.sh` enforce the copy. The task checks also run `cmp` on all three files.

### 5. Tests go into the existing suite and gate section

- **`src/groundx/tests/golang_test.yaml`.** The existing case "database migration blocks upgrades before new Go workloads" now asserts 3600 and 2. Three cases are added: set limits (7200 and 0), the opt-in rendering 2 documents with `helm.sh/hook: pre-upgrade` without `release.upgrade`, and the opt-in with `values.disabled.yaml` rendering 0. "fresh install creates no database upgrade hook" stays as the opt-in-off case. The new cases have no `matchSnapshot`. On the base chart they error on the unknown-key schema rejection, and a scratch run showed that leaves the snapshot file unchanged.
- **`.build/bin/validate-helm.sh`.** The existing "database upgrade hook ships identically" section gains two functions and one loop over `src/groundx helm`:
  - `expect_migration_job_limits` replaces the old full `--is-upgrade` render to `/dev/null`. It still renders the whole chart, then reads the Job's limits with `yq` (defaults `3600 2`, set `7200 0`).
  - `expect_migration_hooks` renders without `--is-upgrade` and lists `kind:hook` for the migration resources (`Job:pre-upgrade Secret:pre-upgrade` with the opt-in, empty without it).
  - The loop calls the existing `expect_helm_template_failure` for the two `minimum` errors. The test plan put these calls in the extract-agent loop (`:323-329`). They are in the migration section instead, with the same helper, so all migration checks sit together.
- **Fail-closed behavior.** The script already runs with `set -euo pipefail`, so a failed render or `yq` aborts it. An empty or missing value never equals the expected string. The positive opt-in case uses the same resource name as the empty off case, so the off case cannot pass because of a wrong name. Renders are captured in variables and never printed.
- **Prototype run.** On 2026-11-18 a scratch copy of these functions passed on a scratch implementation and failed on the base chart with `migration Job deadline and retry count were '900 0', expected '3600 2'`.

### 6. Snapshot update: edit the 5 limit pairs, not a regeneration

`src/groundx/tests/__snapshot__/golang_test.yaml.snap` changes in exactly 5 places: each migration Job's `activeDeadlineSeconds: 900` / `backoffLimit: 0` pair becomes `3600` / `2`. That is 10 changed lines, and nothing else in the file moves.

This knowingly sets aside the `openspec/config.yaml` rule that snapshots are never hand-edited. The human decided this at the rest gate on 2026-11-18. The reason is merge conflicts: three open PRs against `0.3.0` (#167, #173 and #176) also change `golang_test.yaml.snap`, and a `helm unittest -u` regeneration rewrites about 136 lines of it, which would conflict with all three.

The regeneration problem it avoids: on the unchanged base `8f99d2ba`, helm-unittest 1.1.2 with `-u` re-sorted entries, changed key quoting and dropped the two empty entries `'disabled: golang'` and `'workspace-enabled: golang'`. The content is equal as parsed YAML once those empty entries are ignored.

The hand edit is checked against the generator, so it is not trusted on its own. Task 3.1's check proves three things:
- The `git diff` of the file against base consists of exactly those 5 pairs.
- On a `mktemp -d` copy of `src/groundx` that carries the OCR fixture exactly as `validate-helm.sh` writes it, a fresh `helm unittest -u -f tests/golang_test.yaml` produces a file equal to the committed one as parsed YAML, with empty entries ignored.
- On the same copy, a full `helm unittest` run without `-u` passes and leaves every snapshot file byte-identical to the worktree, and no other snapshot file differs from base.

`helm unittest` never runs in the worktree. The PR body says the snapshot was edited by hand for this reason and points at task 3.1's check.

**Rejected:** committing the regenerator's bytes. That is the method the repo rule asks for, but it changes about 136 lines, mostly reordering, and conflicts with the three open PRs above.

### 7. Upgrade guide text

`docs/agents/database-upgrades.md` changes as follows. The task checks match these sentences after collapsing whitespace, so line wrapping is free. The guide makes no claim that a retried history build resumes; that depends on the GroundX image.

Replace the paragraph and example that state "The Job has a 15-minute deadline and no automatic retry" and `--timeout 20m` with:

````markdown
The Job's time limit and retry count are chart values:

- `groundx.migration.activeDeadlineSeconds` (default `3600`) is the time limit
  for the whole Job, in seconds.
- `groundx.migration.backoffLimit` (default `2`) is how many times Kubernetes
  starts a new pod after a failed one.

Retries share the deadline. Each attempt waits up to 30 seconds for the GroundX
migration lock and fails if another process still holds it. When the deadline
passes, Kubernetes stops the Job even if retries remain.

Time `-migrate-only` on a restored snapshot of the database before the upgrade.
Set `activeDeadlineSeconds` above the measured time. Row count is context only:
use the measured time, not an estimate from the number of rows.

Set `--timeout` above the Job deadline plus the time the rollout needs. With the
default deadline, for example:

```sh
helm upgrade groundx ./src/groundx -n eyelevel -f values.yaml --timeout 70m
```

Helm applies `--timeout` to each operation it waits for, including the
migration Job, not to the upgrade as a whole.
````

After "Successful hooks are removed automatically." in "Failure and rollback", add:

````markdown
After a Helm timeout, check whether `<release>-schema-migration` is still
running before you run the upgrade again:

```sh
kubectl get job <release>-schema-migration -n <namespace>
```

The status column in that output exists only on newer clusters. To read the
Job's state on any cluster:

```sh
kubectl get job <release>-schema-migration -n <namespace> \
  -o jsonpath='{.status.active} {.status.conditions[?(@.type=="Failed")].reason}{"\n"}'
```

`1` means the Job is still running. A `Failed` reason means it failed:
`BackoffLimitExceeded` leaves pod logs to read, while `DeadlineExceeded` may
not. `NotFound` means it completed and Helm removed it.

Running the upgrade again deletes the previous migration Job, even one that is
still running, and starts a new one. Wait until the Job has finished first.
````

Append a section:

```markdown
## Argo CD and other GitOps tools

Argo CD renders the chart with `helm template`, so by default it never creates
the migration Job. Set `groundx.migration.gitOps: true` to render the migration
Secret and Job in every render. As with `helm upgrade`, it renders them only
when at least one Go workload is enabled. Argo CD runs Helm `pre-upgrade` hooks
as PreSync hooks, so the Job runs before Argo CD updates any Deployment, on
every sync, including the first.

The database, its credentials, the service account and the image pull Secrets
must exist before PreSync. Do not use `groundx.migration.gitOps` for a first
sync with the bundled MySQL: PreSync runs before Argo CD creates it.

The setting does not change `helm install` or `helm upgrade`. Helm runs the Job
only during an upgrade, with or without it.
```

Sources for the external facts in this text:
- **30-second lock wait and busy-lock error:** cashbot-go `pkg/cbdb/groundx_migration.go:23` and `:27` at `9fc00ccb8`; line 23 is the same at tag `0.2.8`.
- **The deadline covers the whole Job and takes precedence over the retry count:** [Kubernetes Job termination and cleanup](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-termination-and-cleanup).
- **`--timeout` applies to each operation:** Helm v3.19.0 `helm upgrade --help` says "time to wait for any individual Kubernetes operation (like Jobs for hooks)".
- **`before-hook-creation` deletes the previous hook resource:** [Helm chart hooks](https://helm.sh/docs/topics/charts_hooks/#hook-deletion-policies).
- **Argo CD hook mapping and `helm template` rendering:** [Argo CD Helm hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/#helm-hooks).
- **PreSync runs before manifests are applied:** [Argo CD sync phases](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/).

### 8. No chart version bump and no ADR

Release PRs own `Chart.yaml`. The decision is reversible values with recorded defaults, so it does not warrant an ADR.

## Existing mechanisms

| New item | Closest existing mechanism | Decision |
| --- | --- | --- |
| `groundx.migration.activeDeadlineSeconds` / `backoffLimit` values | Hard-coded `activeDeadlineSeconds: 900` / `backoffLimit: 0` in `templates/app/schema-migration.yaml:35-36`. No other template sets Job limits (`grep` of `src/groundx/templates`). | Replace the literals with values. No second mechanism remains. |
| `dig` defaults in the template | `groundx.ranker.api.probe` in `templates/_helpers/app/ranker-api.tpl:189-201` reads probe settings with `dig` and literal defaults | Reuse the same idiom inline. A helper for three reads would be a single-use abstraction. |
| Schema `minimum` | `replicas.gracePeriod` in `values.schema.json` (`"type": "integer", "minimum": 1`) | Same shape. |
| `groundx.migration.gitOps` | The `.Release.IsUpgrade` gate in `schema-migration.yaml:2`. No other template reads `.Release.IsUpgrade` or `.Release.IsInstall`, and the chart has no GitOps or Argo CD setting (`grep` of `src/groundx/templates` and `values.yaml`). | Widen the existing gate. Both conditions stay because they serve different deployers. |
| `expect_migration_job_limits`, `expect_migration_hooks` in `validate-helm.sh` | `expect_helm_template_failure` (`:300`) covers failing renders only. Positive render checks are inline `yq -e` blocks (`:207`, `:341`). | Reuse `expect_helm_template_failure` for rejections. Add two small functions because each positive check runs four times (two inputs, two charts). |

## Shared readers

| Field | Readers | Accepted shape |
| --- | --- | --- |
| `groundx.migration.activeDeadlineSeconds` | `schema-migration.yaml` in both chart copies, which renders it into the Kubernetes Job `spec.activeDeadlineSeconds` | integer of at least 1 |
| `groundx.migration.backoffLimit` | the same template, rendered into Job `spec.backoffLimit` | integer of at least 0 |
| `groundx.migration.gitOps` | the same template's gate only | boolean |

groundx-studio-harness documents these keys in its own change once a published chart carries them (see `contract.md`). It reads the published chart, not this branch.

Producer contract shapes are confirmed in `contract.md`.

## Rollout and blast radius

1. Merge into `0.3.0`. Nothing deploys from a merge.
2. The next chart release cut from `0.3.0` carries the change. Every Helm upgrade with a Go workload then renders a Job with a 3600 s deadline and 2 retries, which is the only rendered difference for unchanged values. Upgrades with a short `--timeout` can now report a Helm failure while the Job keeps running; the guide covers the check.
3. Argo CD users opt in per Application with `groundx.migration.gitOps: true`, after the prerequisites exist.
4. groundx-studio-harness merges its documentation after that chart is published.

There is no SQL, no Secret change, no image change and no change to dev, staging or production values files in this repo. Stateful resources are not touched by the chart.

## Risks / Trade-offs

- **[Risk]** A migration that fails for a lasting reason now runs three times and fails more slowly. **Mitigation:** the guide explains the limits. `backoffLimit: 0` restores the old behavior.
- **[Risk]** A Helm `--timeout` below the new deadline reports failure while the Job still runs, and a rerun replaces that Job. **Mitigation:** the guide's `--timeout 70m` example and the post-timeout check.
- **[Risk]** With the opt-in on, an Argo CD first sync against the bundled MySQL blocks in PreSync. **Mitigation:** off by default, and the guide says not to use it for that case.
- **[Risk]** Argo CD might delete the hook Secret before a retry pod starts. **Mitigation:** task 5.1 checks this on minikube. If it happens, the plan is amended before merge.
- **[Trade-off]** The snapshot is edited by hand against the repo rule, to avoid conflicts with three open PRs (Decision 6). Task 3.1 checks the edit against a fresh regeneration, so a wrong edit fails the check. A later regeneration of this file may still reorder it.

## Migration Plan

- **Deploy:** standard chart release. No ordering constraint with cashbot-go, because the chart and image interact only through `args: ["-migrate-only"]`, the exit status and the config Secret mount, none of which change.
- **Rollback:** set `activeDeadlineSeconds: 900` and `backoffLimit: 0` to restore the old limits, or set `gitOps: false`. `helm rollback` to an earlier chart revision restores the hard-coded limits. Migration steps that already ran are not rolled back.

## Open Questions

None. The snapshot method was decided by the human on 2026-11-18 (Decision 6).
