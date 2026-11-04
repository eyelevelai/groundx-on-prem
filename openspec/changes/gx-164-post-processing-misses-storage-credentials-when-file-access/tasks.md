## 1. Post-process receives the storage Secret (thin slice)

- [x] 1.1 Add the post-process on-case and the paired file-access-off case to `src/groundx/tests/file_settings_test.yaml`, then add `"postProcess"` to `$consumers` in `src/groundx/templates/_helpers/app/file-access.tpl`
  check: helm unittest -f 'tests/file_settings_test.yaml' src/groundx
- [x] 1.2 Mirror the identical `$consumers` change into `helm/templates/_helpers/app/file-access.tpl`
  check: grep -q '"postProcess"' helm/templates/_helpers/app/file-access.tpl && cmp src/groundx/templates/_helpers/app/file-access.tpl helm/templates/_helpers/app/file-access.tpl

## 2. Two-chart gate

- [x] 2.1 Assert the post-process Secret in the FileAccess loop of `.build/bin/validate-helm.sh` so both `src/groundx` and `helm` are rendered
  check: grep -q 'post-process' .build/bin/validate-helm.sh
- [ ] 2.2 Run the full gate and confirm no snapshot changed
  check: n/a — runs the repo CI gate `.build/bin/validate-helm.sh` (also generates the OCR credentials fixture), which needs a full toolchain and a clean tree; it is the verify step, not a behavioral task

See workspace `openspec/changes/<change>/tasks.md` for cross-service coordination and deferred items.
