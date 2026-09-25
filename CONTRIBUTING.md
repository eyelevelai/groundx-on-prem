# Contributing

## Pull Requests

- Keep Helm chart changes in `src/groundx/` first; mirror to `helm/` when the
  change needs to ship through the published chart.
- Explain chart behavior in committed comments only when it captures a
  non-obvious invariant, operational risk, or template constraint.
- Put ticket discussion, rejected approaches, and implementation history in
  Linear, OpenSpec, or the PR body.
- Call out any `src/groundx/` to `helm/` mirror work in the PR.

## Validation

Read the source template, its values and helpers, rendered consumers, and
existing chart tests before changing it. Reuse the current chart pattern and
make the smallest change that preserves dependent installs. Extend an existing
Helm test or render check when it can prove the consequential deployment
behavior; add a new case only when the existing coverage cannot. Keep required
render, snapshot, and approval checks.

- Run `helm unittest src/groundx` for chart logic or snapshot changes.
- Run `helm template` or an existing focused render command for values/template
  changes.
- For docs-only changes, run `git diff --check` before pushing.
