# Tasks

- [x] Add chart tests for default and configured domain rendering. The configured test initially failed because the strict schema rejected the new field.
- [x] Add source chart values, schema, and config rendering.
- [x] Mirror the three changed chart files into `helm/`.
- [x] Verify `.build/bin/validate-helm.sh` and the minikube template render pass. Verify the schema rejects a scalar and duplicate domains.
- [ ] Release or install the chart and verify the rendered live config. Hosted-Lambda config and deployment remain separate Cashbot operations.
