## 1. Contract

- [x] 1.1 Replace the document-summary fallback requirement with the current
  engine-wide, opt-in `maxImages` behavior.
- [x] 1.2 Leave schema, templates, chart values, and Kubernetes resources
  unchanged.

## 2. Validation

- [x] 2.1 Run strict OpenSpec validation.
- [x] 2.2 Run Helm lint, template rendering, and unit tests.
- [x] 2.3 Run `git diff --check` and confirm no chart files changed.

## 3. Rollout

- [x] 3.1 Record that no deployment, canary, secret change, migration, or
  manual operation is required for this documentation-only correction.
