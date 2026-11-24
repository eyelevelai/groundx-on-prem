## Why

The GroundX image shipped with chart 0.2.8 adds a one-time migration step that reads every past ingest task to build file-access history. On a large database that step takes longer than the chart's migration Job allows, and no chart path can finish it. In a production upgrade from 0.2.7 to 0.2.8 on 2026-10-29 (Argo CD, about 5.8 GiB of MySQL), the migration finished only after someone ran `groundx -migrate-only` by hand as a separate Job with a two-hour deadline (GX-152).

Two limits in `src/groundx/templates/app/schema-migration.yaml` cause this. The file is the same on branch `0.3.0` at `8f99d2ba` and in the `helm/` mirror.

- The pre-upgrade Job hard-codes `backoffLimit: 0` and `activeDeadlineSeconds: 900` (lines 35-36). Operators cannot raise the 15-minute deadline. One failed attempt ends the upgrade, including the attempt that exits after waiting 30 s for a busy migration lock.
- The Secret and Job render only when `.Release.IsUpgrade` is true (line 2). Argo CD renders charts with `helm template`, which leaves that flag false. Under Argo CD the Job never exists, so nothing runs the migration before the new pods roll out ([Argo CD Helm guide](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)).

## What Changes

- **Job deadline and retry count become values.** `groundx.migration.activeDeadlineSeconds` defaults to 3600 and must be an integer of at least 1. `groundx.migration.backoffLimit` defaults to 2 and must be an integer of at least 0. An explicit `backoffLimit: 0` renders as 0 and is not replaced by the default.
- **Defaults change for every Helm upgrade that renders the Job.** The deadline goes from 900 s to 3600 s, and the retry count goes from 0 to 2. A Kubernetes Job deadline covers all of the Job's pods, so retries share the 3600 s ([Kubernetes Job termination](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-termination-and-cleanup)). These two numbers are the only rendered difference when no new value is set.
- **GitOps opt-in.** When `groundx.migration.gitOps` (boolean, default false) is true, the chart renders the existing migration Secret and Job even when `.Release.IsUpgrade` is false. The Job still renders only when at least one Go workload is enabled. The hook annotations stay as they are: `helm.sh/hook: pre-upgrade`, weights `-10` for the Secret and `-5` for the Job, and delete policy `before-hook-creation,hook-succeeded`. Argo CD treats a Helm `pre-upgrade` hook as a PreSync hook, so it runs the Job before it applies the Deployments. It does this on every sync, including the first ([Argo CD Helm hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/#helm-hooks)). With the value off, the chart behaves as it does today.
- **Values contract.** Both `values.yaml` files gain a `groundx.migration` block with the three defaults. Both `values.schema.json` files gain a matching object with `additionalProperties: false`. The `groundx` object already rejects unknown keys.
- **Both chart copies change together.** The template, `values.yaml` and `values.schema.json` change identically in `src/groundx` and `helm/`. `verify_mirrors()` byte-compares all three (`.build/bin/verify-storage-contract.py:144-155`), and `validate-helm.sh` also runs `cmp` on the template (line 561).
- **Upgrade docs.** `docs/agents/database-upgrades.md` replaces the "15-minute deadline and no automatic retry" text and the `--timeout 20m` example (lines 52-56) with the following guidance:
  - Time `-migrate-only` on a restored snapshot first. Row count is context only.
  - Set `--timeout` above the Job deadline plus the rollout, for example `--timeout 70m`.
  - Retries share the deadline. A retry gives up if another process holds the lock for more than 30 s.
  - After a Helm timeout, check whether `<release>-schema-migration` is still running before running the upgrade again.
  - The GitOps opt-in needs the database, credentials, service account and image pull Secrets to exist before PreSync. Do not use it for a first sync with the bundled MySQL.
- **No chart version bump and no image tag change.** Release PRs own `Chart.yaml`.

Not breaking: both new keys are optional, and every values file that chart 0.2.9 accepts is still accepted.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `database-upgrade-gate`: operators can set the migration Job's deadline and retry count, which default to 3600 s and 2 and are checked by the schema. An off-by-default opt-in renders the migration Secret and Job without `.Release.IsUpgrade`, so Argo CD runs them before rollout. The existing fresh-install, worker-only and no-Go-workload requirements still hold while the opt-in is off.

## Impact

- **Code:** in both chart copies, `templates/app/schema-migration.yaml`, `values.yaml` and `values.schema.json`. Also `src/groundx/tests/golang_test.yaml`, its snapshot, `.build/bin/validate-helm.sh`, `docs/agents/database-upgrades.md`, and a delta for `openspec/specs/database-upgrade-gate/spec.md`.
- **Tests:** chart cases go into the existing `golang_test.yaml` migration cases (from line 60). Only the 5 migration Job limit pairs in the snapshot are edited by hand, and a check proves the file equals a fresh `helm unittest -u` run on a scratch copy as parsed data. Regenerating would reorder about 136 lines and conflict with three open PRs against 0.3.0. The existing both-chart render loop in `validate-helm.sh` and its `expect_helm_template_failure` cases cover the defaults and the schema rejections for both charts. A minikube Argo CD run shows the opt-in ordering and the Secret's lifetime across a retry. `.build/bin/validate-helm.sh` gates the change.
- **Consumers:** the GroundX image's interface does not change: `args: ["-migrate-only"]`, exit status and the config Secret mount. Resuming a retried history build is a separate cashbot-go change under the same ticket. This repo's docs do not promise resume. groundx-studio-harness documents the new keys in its own change, which waits until a published chart carries them. Customer Argo CD and deployment repositories are out of scope.
- **Blast radius:** this affects only installs that upgrade to a chart release containing this change.
  - Helm installs with Go workloads get the longer deadline and two retries. A migration that would have stopped at 15 minutes now runs up to 60. If `--timeout` is shorter, Helm reports a failure while the Job keeps running.
  - A migration that fails for a lasting reason now runs three times before the upgrade fails, which means a slower failure and more pod logs.
  - Argo CD installs see no change until they set `groundx.migration.gitOps: true`. After that, the Job runs on every full sync (a sync of selected resources skips hooks) and needs its prerequisites in place before PreSync.
  - Whether Argo CD keeps the hook Secret while a retry pod starts will be checked in the minikube run. If it does not, the fix changes hook annotations or delete policy, which needs the plan approved again.
- **Environments:** self-hosted customer clusters that deploy with Helm or Argo CD. Hosted GroundX deployments migrate in a separate operator step and are not affected. No dev, staging or production values file in this repo changes. Testing uses a disposable minikube cluster.
- **Data and stateful resources:** the chart runs no SQL of its own and changes no stored data. Each Job attempt runs the same `-migrate-only` against the configured database under the existing GroundX migration lock. Already-applied steps are kept between attempts (`docs/agents/database-upgrades.md:74`). With the opt-in on, the existing migration Secret, which holds database settings, also exists as a hook resource during Argo CD syncs.
- **Rollback / roll-forward:**
  - To restore the old limits, set `activeDeadlineSeconds: 900` and `backoffLimit: 0`.
  - To stop rendering under Argo CD, set `gitOps: false`.
  - `helm rollback` to an earlier chart revision brings back the hard-coded limits. Migration steps that already ran are not rolled back.
  - To roll forward after a deadline is hit, raise `activeDeadlineSeconds`, confirm the previous Job has stopped, then upgrade again.
- **Open design questions:** none. The ticket's desired behavior, the human-approved approach and the plan gate settled the value names, defaults, opt-in shape and test approach.
