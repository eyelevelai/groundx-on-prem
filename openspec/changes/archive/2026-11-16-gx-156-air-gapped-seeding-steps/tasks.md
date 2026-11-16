## 1. Upgrade guide

- [x] 1.1 In `docs/upgrades.md` § "Inference model downloads", make the false-marker recovery send an air-gapped cluster to re-seed, and replace the air-gapped paragraph with the numbered seeding procedure (connected-machine download, scale to 0 and wait, short-lived pod as user 1001, extract in part order, marker last, scale up), naming only ranker and summary and the model-change case, without naming a chart version
  check: s=$(awk '/^## Inference model downloads/{f=1;next} f&&/^## /{exit} f' docs/upgrades.md) && for n in 'On an air-gapped cluster the pod cannot download it' 'short-lived pod' 'create `complete.<model>` last' 'Only the ranker and summary pods download a model' 'before an upgrade that changes a service' 'runs as user and group `1001`'; do printf '%s' "$s" | grep -qF -- "$n" || exit 1; done && ! printf '%s' "$s" | grep -qE 'chart [0-9]+\.[0-9]+' && ! printf '%s' "$s" | grep -qF 'Copy the model files and the `complete.<model>` file into the model volume before scaling up'
- [ ] 1.2 Run the full gate `.build/bin/validate-helm.sh`
  check: n/a — privileged gate script, run by the push gate and CI, not by a task check
