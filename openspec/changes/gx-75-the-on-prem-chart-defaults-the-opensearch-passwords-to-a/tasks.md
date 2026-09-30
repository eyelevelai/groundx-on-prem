# Tasks - GX-75: Remove the public default OpenSearch passwords (groundx-on-prem)

Commit subjects use `GX-75: <subject>`. Helm checks use the pinned v3.19.0 (`GX_ON_PREM_HELM`, default `$HOME/.local/bin/helm-v3.19.0`); the bare `helm` on PATH may be v4. Never run `helm unittest -u`, never print rendered manifests or the literal. On the unchanged base every check below FAILS (RED) and passes once the task is done. The literal is always read from base revision `57cb29b3` at check time (`git show 57cb29b3:src/groundx/values.yaml`), never typed here.

Gate 0 (main loop, before apply): the throwaway local probe of the seed image's `OPENSEARCH_INITIAL_ADMIN_PASSWORD` behaviour is human-gated and is not a task in this file. Task 3.2, task 4.1 and design D4 depend on its outcome.

## 1. Thin slice: `src/groundx` fails closed on a missing key, ingest stays clean

- [ ] 1.1 `groundx.search.password` and `groundx.search.privilegedPassword` drop their `dig` fallback; with `mode` not `ingest` an empty or absent value fails the render naming `search.password` or `search.privilegedPassword`.
  check: bash -c 'H=${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}; ! $H template t src/groundx >/dev/null 2>&1 && $H template t src/groundx 2>&1 >/dev/null | grep -q "search\.password" && $H template t src/groundx --set search.password=test-app-only 2>&1 >/dev/null | grep -q "search\.privilegedPassword" && $H template t src/groundx --set search.privilegedPassword=test-admin-only 2>&1 >/dev/null | grep -q "search\.password"'
- [ ] 1.2 With `mode: ingest` the render succeeds with no search passwords and renders no search password even when one is supplied (`config-yaml.yaml` skips both search password lines).
  check: bash -c 'H=${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}; $H template t src/groundx --set mode=ingest >/dev/null 2>&1 && ! $H template t src/groundx --set mode=ingest --set search.password=ingest-sentinel-a --set search.privilegedPassword=ingest-sentinel-b 2>/dev/null | grep -q ingest-sentinel'
- [ ] 1.3 `values.yaml` in both trees keeps `search.password` and `search.privilegedPassword` as empty strings (the schema requires the keys); both `values.aws.services.yaml` files drop the two password keys.
  check: bash -c 'yq -e ".search.password == \"\" and .search.privilegedPassword == \"\"" src/groundx/values.yaml helm/values.yaml >/dev/null && yq -e "(.search | has(\"password\") | not) and (.search | has(\"privilegedPassword\") | not)" src/groundx/values/values.aws.services.yaml helm/values/values.aws.services.yaml >/dev/null'
- [ ] 1.4 One literal-free fixture `src/groundx/tests/files/values.search-credentials.yaml` carries two distinct non-empty test-only values and renders the chart cleanly.
  check: bash -c 'H=${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}; f=src/groundx/tests/files/values.search-credentials.yaml; test -f $f && yq -e ".search.password != \"\" and .search.privilegedPassword != \"\" and .search.password != .search.privilegedPassword" $f >/dev/null && $H template t src/groundx -f $f >/dev/null 2>&1'
- [ ] 1.5 Every helm-unittest suite that renders `config-yaml.yaml` loads the fixture at suite level, `resources_test.yaml.snap` is hand-patched (each literal replaced by the fixture value of the matching key, never `-u`), and the acceptance cases already written in `resources_test.yaml` pass.
  check: bash -c 'grep -q "values.search-credentials.yaml" src/groundx/tests/resources_test.yaml && grep -q "values.search-credentials.yaml" src/groundx/tests/workspace_test.yaml && grep -q "values.search-credentials.yaml" src/groundx/tests/anthropic_test.yaml && grep -q "values.search-credentials.yaml" src/groundx/tests/ranker_test.yaml && grep -q fixture-admin-credential src/groundx/tests/__snapshot__/resources_test.yaml.snap'

## 2. `helm/` mirror

- [ ] 2.1 The `helm/` mirror carries the same helper and `config-yaml.yaml` behavior: default render fails naming the key, and the four files that are byte-identical to `src/groundx` today stay identical.
  check: bash -c 'H=${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}; ! $H template t helm >/dev/null 2>&1 && $H template t helm 2>&1 >/dev/null | grep -q "search\.password" && for f in templates/_helpers/services/search.tpl templates/resources/config-yaml.yaml values/opensearch/values.yaml values/values.aws.services.yaml; do cmp -s src/groundx/$f helm/$f || exit 1; done'
- [ ] 2.2 The `helm/` unit suite (`helm/tests/search_credentials_test.yaml`, already written: empty `search.password`, empty `search.privilegedPassword`, ingest sentinel) passes.
  check: bash -c 'H=${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0}; $H unittest helm >/dev/null 2>&1'

## 3. Remove the literal everywhere

- [ ] 3.1 The literal (read from base revision `57cb29b3`, refusing to pass if it cannot be read) is absent from every tracked and untracked-unignored file: values, seed files, sample, AWS values, snapshot, Terraform defaults and examples, this change folder.
  check: bash -c 'l=$(git show 57cb29b3:src/groundx/values.yaml | yq -r ".search.password") && [ ${#l} -gt 8 ] && ! git grep -q --untracked -F -e "$l"'
- [ ] 3.2 Both OpenSearch seed values files (`helm/values/opensearch/values.yaml`, `src/groundx/values/opensearch/values.yaml`) no longer define `OPENSEARCH_INITIAL_ADMIN_PASSWORD`, stay identical to each other, and keep the seed image repository.
  check: bash -c '! grep -q OPENSEARCH_INITIAL_ADMIN_PASSWORD src/groundx/values/opensearch/values.yaml helm/values/opensearch/values.yaml && cmp -s src/groundx/values/opensearch/values.yaml helm/values/opensearch/values.yaml && yq -e ".image.repository == \"eyelevel/opensearch\"" helm/values/opensearch/values.yaml >/dev/null'
- [ ] 3.3 `sample.values.yaml` sets both search passwords to empty strings (fail closed until the operator fills them).
  check: bash -c 'yq -e ".search.password == \"\" and .search.privilegedPassword == \"\"" sample.values.yaml >/dev/null'

## 4. README

- [ ] 4.1 README `### OpenSearch` passes the operator-supplied admin password (`OPENSEARCH_INITIAL_ADMIN_PASSWORD`, placeholder only) through a local, uncommitted, `chmod 600` values file `opensearch-admin.values.yaml` added with a second `-f` on the `helm install opensearch opensearch/opensearch` command (never `--set`), and says the value must equal `search.privilegedPassword`.
  check: bash -c 's=$(sed -n "/^### OpenSearch/,/^### Kafka/p" README.md); grep -q OPENSEARCH_INITIAL_ADMIN_PASSWORD <<<"$s" && grep -q "search.privilegedPassword" <<<"$s" && grep -Eq "helm install opensearch opensearch/opensearch.* -f opensearch-admin.values.yaml" <<<"$s" && grep -q "chmod 600" <<<"$s" && ! grep -Eq -- "--set[^\n]*(ADMIN_PASSWORD|extraEnvs)" <<<"$s"'
- [ ] 4.2 README `### Configuration` minimal-keys block lists `search.password` and `search.privilegedPassword` as required when `mode` is not `ingest`.
  check: bash -c 's=$(sed -n "/^### Configuration/,/^### Persistent Storage/p" README.md); grep -q "search.password" <<<"$s" && grep -q "search.privilegedPassword" <<<"$s" && grep -q "mode.*ingest" <<<"$s"'
- [ ] 4.3 README carries the migration note under a `#### Upgrading an Existing Install` heading (current admin password to `search.privilegedPassword`, current application password to `search.password`, then rotate; a wrong admin password crash-loops the GroundX API).
  check: bash -c 's=$(sed -n "/^#### Upgrading an Existing Install/,/^###/p" README.md); grep -qi "crash" <<<"$s" && grep -q "search.privilegedPassword" <<<"$s" && grep -q "search.password" <<<"$s"'

## 5. Terraform operator

- [ ] 5.1 `variable "search"` has no default and rejects an empty `password` and, separately, an empty `root_password`; complete non-empty input is accepted. Probed on an extracted copy of the variable block through `terraform plan` (no providers needed).
  check: bash -c 'd=$(mktemp -d); awk "/^variable \"search\" \{/,/^\}/" terraform/groundx-operator/operator/variables.tf > $d/v.tf; printf "output \"o\" { value = var.search.index }\n" >> $d/v.tf; cd $d && terraform init -backend=false >/dev/null 2>&1; p() { terraform plan -input=false -var "search={index=\"i\",user=\"u\",password=\"$1\",root_password=\"$2\"}" >/dev/null 2>&1; }; p a b && ! p "" b && ! p a "" && ! terraform plan -input=false >/dev/null 2>&1'
- [ ] 5.2 `env.tfvars.example` and `env.tfvars.example-openshift` show angle-bracket placeholders (no colon) for both search passwords and keep `index` and `user`.
  check: bash -c 'for f in terraform/groundx-operator/operator/env.tfvars.example terraform/groundx-operator/operator/env.tfvars.example-openshift; do b=$(awk "/^search = \{/,/^\}/" $f); [ "$(grep -Ec "^ *(root_)?password *= *\"<[^:>]+>\"" <<<"$b")" -eq 2 ] && grep -q "index" <<<"$b" && grep -q "user" <<<"$b" || exit 1; done'

## 6. Gates and declared render commands

- [ ] 6.1 The CI workflow render commands and the render checks declared in `service.yaml`, `openspec/config.yaml` and `AGENTS.md` pass the fixture; nothing is added to `values/minikube` or any install example.
  check: bash -c 'for f in .github/workflows/helm-tests.yml service.yaml openspec/config.yaml AGENTS.md; do grep -q "values.search-credentials.yaml" $f || exit 1; done; ! grep -q "search" src/groundx/values/minikube/values.yaml'
- [ ] 6.2 `.build/bin/validate-helm.sh` and the `verify-*` scripts it runs render with the fixture and the whole gate passes (with `helm` resolving to v3.19.0 on PATH).
  check: bash -c 'd=$(mktemp -d); ln -s ${GX_ON_PREM_HELM:-$HOME/.local/bin/helm-v3.19.0} $d/helm; PATH=$d:$PATH .build/bin/validate-helm.sh >/dev/null 2>&1'

See workspace `openspec/changes/gx-75-the-on-prem-chart-defaults-the-opensearch-passwords-to-a/tasks.md` for cross-service coordination and deferred items.
