# Contributing

## Pull Requests

- Follow the [customer documentation rules](docs/agents/repository-guide.md#customer-facing-documentation)
  for the README and customer guides. Keep optional features and detailed
  operating procedures in linked guides.
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

- Run `.build/bin/validate-helm.sh` for chart logic or snapshot changes. It creates
  the temporary OCR test credentials and verifies the pinned test plugin.
- Run `helm template` or an existing focused render command for values/template
  changes.
- For docs-only changes, run `git diff --check` before pushing.

## Workspace validation

Run the local Helm production gate before changing chart helpers, values, schemas, or snapshots:

```bash
.build/bin/validate-helm.sh
```

The Helm CI gate uses the same script. It lints both chart surfaces, runs Helm unittest, verifies that snapshots did not silently drop empty renders, runs `.build/bin/verify-workspace-chart.py` to prove the workspace API service and metrics contracts stay aligned, and runs `.build/bin/verify-storage-contract.py` to prove StorageClass defaults, provider examples, PVC access modes, mirrored chart files, and the `setup-eks` generated EFS/EBS values and printed Helm commands all render.
