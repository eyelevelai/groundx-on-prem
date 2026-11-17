## Decision

Keep the independent branch-push Helm validation, release checks and manual dispatch. Fail the required Helm PR job before setup on drafts and defer both kind jobs. Add a PR-only check that requires successful results from all three jobs and cannot be satisfied by branch-push results.

## Validation

Check that ready PRs run all three jobs, drafts fail closed, and push, manual and release behavior is preserved. Before merge an administrator must configure the PR-only check on main and the active chart release branch.
