# Design — GX-63 (groundx-on-prem): upload hold note in the AWS example values

Grounding: `proposal.md` states the problem and the scope. This is a comment-only change; the
5 minute upload lease itself ships in cashbot-go under GX-63.

## Decisions

- **Wording.** Replace the line `# visibility timeout must be 10+ min for all SQS queues` (line 59 of
  `src/groundx/values/values.aws.services.yaml`, directly above `topics:`) with
  two comment lines: `# visibility timeout must be 10+ min for all SQS queues. Upload re-hides its in-flight messages for 5 min, renewed every minute, so a crashed upload pod's messages return about 5 min after their last renewal.` and `# If the upload queue has a DLQ, maxReceiveCount must be at least 4, since delivery 4 is the first one that errors the document; 3 or less sends it to the DLQ first.`.
  Two lines, so the comment keeps its place above `topics:` and every queue keeps the
  existing 10+ minute rule. The note says what the upload consumer does, not what the queue
  timeout must be, because the lease is set by the consumer after it starts processing.
- **Edit order.** `src/groundx/` first, then the identical line in `helm/values/values.aws.services.yaml`
  by hand. The files are byte-identical today and stay byte-identical. The mirror guard
  (`verify_mirrors()` in `.build/bin/verify-storage-contract.py`) compares the `templates/` tree,
  not `values/`, so nothing in the gate would catch a missed mirror edit; the task check compares
  the two values files directly.
- **Render invariance is the proof.** A YAML comment is dropped by the parser. The task check
  renders `helm template` once with the edited file and once with the comment lines stripped from
  it and requires identical output. `values.aws.services.yaml` is also an input to the existing
  helm-unittest suites (for example `tests/api_test.yaml`), so those snapshots staying green is a
  second signal and is covered by the push gate.

## Rollout & blast radius

- No environment (dev/staging/prod) redeploys: manifests, config hashes, and pod specs do not change,
  so no workload restarts and no stateful resource is touched.
- The chart version is not bumped and no release artifact is regenerated for a comment.
- Rollback: revert the commit. Nothing to migrate.
- Branch: groundx-on-prem work branches from `main` (recorded in the workspace design).
- Gate: `validate-helm.sh` runs only through the repo's own pre-push hook; it is not run by hand.

## Not decided here

- No ADR: the change records existing behavior shipped elsewhere and has no alternatives to weigh.
- No new spec capability: the one added requirement sits in `values-contract-semantics`, which already
  owns source/mirror agreement for values.
