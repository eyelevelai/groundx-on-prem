## Why

Draft PRs start the two live Strimzi jobs even though the changes are still in progress.

## What Changes

Keep the independent branch-push Helm validation, release checks and manual dispatch. Fail the required Helm PR job before setup on drafts and defer both kind jobs. Add a PR-only check that requires successful results from all three jobs and cannot be satisfied by branch-push results.

## Capabilities

### New Capabilities

- `review-ready-ci`: Define which pull request checks run and what is required for merge.

### Modified Capabilities

None.

## Impact

GitHub Actions workflows and contributor guidance.
