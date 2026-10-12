## 1. Thin slice: the note on both values files

- [x] 1.1 In `src/groundx/values/values.aws.services.yaml` line 59, change the comment to `# visibility timeout must be 10+ min for all SQS queues except upload, which holds in-flight messages for 5 min`
  check: grep -qF '# visibility timeout must be 10+ min for all SQS queues except upload, which holds in-flight messages for 5 min' src/groundx/values/values.aws.services.yaml
- [x] 1.2 Apply the identical line to the manual mirror `helm/values/values.aws.services.yaml`, leaving both values files byte-identical
  check: grep -qF '# visibility timeout must be 10+ min for all SQS queues except upload, which holds in-flight messages for 5 min' helm/values/values.aws.services.yaml && cmp -s src/groundx/values/values.aws.services.yaml helm/values/values.aws.services.yaml

## 2. Rendered output is unchanged

- [x] 2.1 Confirm the edited `src` values file renders the same manifests as a copy with its comment lines removed
  check: T=$(mktemp -d) && grep -qF 'except upload, which holds in-flight messages for 5 min' src/groundx/values/values.aws.services.yaml && grep -v '^ *#' src/groundx/values/values.aws.services.yaml > "$T/stripped.yaml" && helm template src/groundx -f src/groundx/values/values.aws.services.yaml > "$T/with.yaml" && helm template src/groundx -f "$T/stripped.yaml" > "$T/without.yaml" && cmp -s "$T/with.yaml" "$T/without.yaml"
- [x] 2.2 Confirm the same for the published `helm` chart and its mirrored values file
  check: T=$(mktemp -d) && grep -qF 'except upload, which holds in-flight messages for 5 min' helm/values/values.aws.services.yaml && grep -v '^ *#' helm/values/values.aws.services.yaml > "$T/stripped.yaml" && helm template helm -f helm/values/values.aws.services.yaml > "$T/with.yaml" && helm template helm -f "$T/stripped.yaml" > "$T/without.yaml" && cmp -s "$T/with.yaml" "$T/without.yaml"

## 3. Gate

- [ ] 3.1 Push gate: `validate-helm.sh` (lint, helm unittest, contract verifiers) runs through the repo's pre-push hook on the feature branch
  check: n/a — validate-helm.sh runs only through the repo's own pre-push hook, never by hand

See workspace `openspec/changes/gx-63-upload-messages-stay-hidden-for-15-minutes-after-a-worker/tasks.md` for cross-service coordination and deferred items.
