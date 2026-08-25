## 1. Summary API key (first vertical slice — mirrors `extract.agent` exactly)

- [x] 1.1 In `src/groundx/`: add `summary.existing.existingSecret` (boolean) to
  `values.schema.json`; add `groundx.summary.existingSecret`, `groundx.summary.secretName`
  (fixed `summary-secret`), and `groundx.summary.apiKeyEnv` (`GROUNDX_SUMMARY_API_KEY`) to
  `templates/_helpers/app/summary.tpl`; extend `groundx.app.secrets`
  (`templates/_helpers/app/secrets.tpl`) with a `summary` entry mirroring the existing
  `extract.agent` entry (create the Secret when `apiKey!="" AND existingSecret==false`; wire
  `envFrom` — chart-created or pre-existing per `existingSecret` — into `groundx.groundx.settings`'s
  `secrets` dict in `templates/_helpers/app/groundx.tpl` whenever `apiKey!="" OR
  existingSecret=="true"`).
  check: helm unittest src/groundx -f 'tests/summary-secret_test.yaml'
- [x] 1.2 Mirror the four changed files from 1.1 into `helm/` byte-for-byte.
  check: diff src/groundx/values.schema.json helm/values.schema.json && diff src/groundx/templates/_helpers/app/summary.tpl helm/templates/_helpers/app/summary.tpl && diff src/groundx/templates/_helpers/app/groundx.tpl helm/templates/_helpers/app/groundx.tpl && diff src/groundx/templates/_helpers/app/secrets.tpl helm/templates/_helpers/app/secrets.tpl && grep -q 'summary-secret' helm/templates/_helpers/app/summary.tpl

## 2. OpenSearch credentials

- [x] 2.1 In `src/groundx/`: add `search.existingSecret` (boolean) to `values.schema.json`; add
  `groundx.search.existingSecret` and `groundx.search.secretName` (fixed `opensearch-secret`) to
  `templates/_helpers/services/search.tpl` — **no auto-create branch** (see design.md D2/D3: the
  chart never creates this Secret from the non-empty default plaintext values, only references a
  pre-existing one when `existingSecret==true`); make the four fields in `config-yaml.yaml`'s
  `ai.aws.search.{username,password}` and `init.search.{username,password}` conditional on
  non-empty (mirroring the existing `admin.*`/`ai.openai.apiKey` conditional pattern in the same
  file, not a new one); wire `SEARCH_USERNAME`/`SEARCH_PASSWORD`/`SEARCH_PRIVILEGED_USERNAME`/
  `SEARCH_PRIVILEGED_PASSWORD` into `groundx.groundx.settings`'s `secrets` dict
  (`templates/_helpers/app/groundx.tpl`) only when `existingSecret=="true"`.
  check: helm unittest src/groundx -f 'tests/search-secret_test.yaml'
- [x] 2.2 Mirror the three changed files from 2.1 into `helm/` byte-for-byte.
  check: diff src/groundx/values.schema.json helm/values.schema.json && diff src/groundx/templates/_helpers/services/search.tpl helm/templates/_helpers/services/search.tpl && diff src/groundx/templates/resources/config-yaml.yaml helm/templates/resources/config-yaml.yaml && diff src/groundx/templates/_helpers/app/groundx.tpl helm/templates/_helpers/app/groundx.tpl && grep -q 'opensearch-secret' helm/templates/_helpers/services/search.tpl

## 3. Redis AUTH (external cache only)

- [x] 3.1 In `src/groundx/`: add `cache.existing.password` (string) and
  `cache.existing.existingSecret` (boolean) to `values.schema.json`; add
  `groundx.cache.password` and `groundx.cache.existingSecret` to
  `templates/_helpers/services/cache.tpl`, both returning empty/false unless
  `cache.existing.addr` is set (external Redis only — the bundled Redis Deployment is untouched);
  extend `groundx.secrets` (`templates/_helpers/main.tpl`) to fold in a `redis-secret` entry —
  created from `cache.existing.password` when non-empty and `existingSecret==false`, or referenced
  (not created) when `existingSecret==true` — so it reaches every workload pod type through the
  existing universal `envFrom` mechanism (design.md D4) with **zero edits to any of the five app
  pod templates**.
  check: helm unittest src/groundx -f 'tests/redis-auth_test.yaml'
- [x] 3.2 Mirror the two changed files from 3.1 into `helm/` byte-for-byte.
  check: diff src/groundx/values.schema.json helm/values.schema.json && diff src/groundx/templates/_helpers/services/cache.tpl helm/templates/_helpers/services/cache.tpl && diff src/groundx/templates/_helpers/main.tpl helm/templates/_helpers/main.tpl && grep -q 'redis-secret' helm/templates/_helpers/main.tpl

## 4. Application API keys (extract/ranker) — gate-class: same invariant at 5 pod sites

Invariant (see design.md `## Decisions` opening + spec.md polarity scenarios): a plaintext
`admin.apiKey`/`admin.username` value always renders literally and wins; the
`os.environ.get(...)` fallback and `groundx-admin-secret` `envFrom` are wired only when
`admin.existingSecret==true`, independent of whether the plaintext value is also set — never the
other way around.

- [x] 4.1 In `src/groundx/`: add `admin.existingSecret` (boolean) to `values.schema.json`; add
  `groundx.admin.existingSecret` and `groundx.admin.secretName` (fixed `groundx-admin-secret`) to
  `templates/_helpers/main.tpl`; extend `groundx.app.secrets`
  (`templates/_helpers/app/secrets.tpl`) with an `admin` entry (create from
  `admin.apiKey`/`admin.username` when either is non-empty and `existingSecret==false`; reference
  pre-existing when `existingSecret==true`); in `templates/resources/extract-config-py.yaml`, add
  `import os` to the generated module header and switch `callback_api_key`/`api_key` (sourced from
  `groundx.extract.callbackApiKey`, which defaults to `admin.username`) and the `admin.apiKey`/
  `admin.username` entries inside `valid_api_keys=[...]` to
  `os.environ.get("GROUNDX_ADMIN_USERNAME", "")` / `os.environ.get("GROUNDX_ADMIN_API_KEY", "")`
  when the sourced value is empty and `existingSecret==true` (config still wins when non-empty);
  apply the same treatment to `validAPIKeys=[...]` in `templates/resources/ranker-config-py.yaml`.
  check: helm unittest src/groundx -f 'tests/app-api-keys-secret_test.yaml'
- [x] 4.2 Wire the `groundx-admin-secret` `envFrom` entry into each of the five pods whose config
  bakes these values — add the same conditional `secrets` dict entry
  (`admin!="" OR existingSecret=="true"` → include `groundx.admin.secretName`) to
  `groundx.extract.agent.settings` (`templates/_helpers/app/extract-agent.tpl`),
  `groundx.extract.download.settings` (`templates/_helpers/app/extract-download.tpl`),
  `groundx.extract.save.settings` (`templates/_helpers/app/extract-save.tpl`),
  `groundx.ranker.api.settings` (`templates/_helpers/app/ranker-api.tpl`), and
  `groundx.ranker.inference.settings` (`templates/_helpers/app/ranker-inference.tpl`).
  check: helm unittest src/groundx -f 'tests/app-api-keys-secret_test.yaml'
- [x] 4.3 Mirror the eight changed files from 4.1/4.2 into `helm/` byte-for-byte.
  check: diff src/groundx/values.schema.json helm/values.schema.json && diff src/groundx/templates/_helpers/main.tpl helm/templates/_helpers/main.tpl && diff src/groundx/templates/_helpers/app/secrets.tpl helm/templates/_helpers/app/secrets.tpl && diff src/groundx/templates/resources/extract-config-py.yaml helm/templates/resources/extract-config-py.yaml && diff src/groundx/templates/resources/ranker-config-py.yaml helm/templates/resources/ranker-config-py.yaml && diff src/groundx/templates/_helpers/app/extract-agent.tpl helm/templates/_helpers/app/extract-agent.tpl && diff src/groundx/templates/_helpers/app/extract-download.tpl helm/templates/_helpers/app/extract-download.tpl && diff src/groundx/templates/_helpers/app/extract-save.tpl helm/templates/_helpers/app/extract-save.tpl && diff src/groundx/templates/_helpers/app/ranker-api.tpl helm/templates/_helpers/app/ranker-api.tpl && diff src/groundx/templates/_helpers/app/ranker-inference.tpl helm/templates/_helpers/app/ranker-inference.tpl && grep -q 'groundx-admin-secret' helm/templates/_helpers/main.tpl

## 5. Google OCR credential (Secret-volume, additive to the packaged file — GX-11 boundary)

Do **not** edit `templates/app/celery.yaml` for this family — use the existing generic
`volumes`/`volumeMounts` extension point in `groundx.layout.ocr.settings` (design.md D5) so the
GX-11 `hasOCR` `-}}`-guarded conditional (lines ~66-68, ~174-178, ~189-193 of `celery.yaml`) is
never opened. If implementing this without touching those lines turns out to be impossible,
escalate-and-stop rather than editing them.

- [x] 5.1 In `src/groundx/`: add `layout.ocr.existingSecret` (boolean) to `values.schema.json`; in
  `templates/_helpers/app/layout-ocr.tpl`, add `groundx.layout.ocr.existingSecret` and
  `groundx.layout.ocr.secretName` (fixed `layout-ocr-secret`); in `groundx.layout.ocr.settings`,
  `fail` the render when both `layout.ocr.credentials` and `layout.ocr.existingSecret` are set
  (mirroring `groundx.extract.agent.validateImageSettings`'s existing `fail` convention), and
  otherwise, when `existingSecret==true`, add a `credentials-secret-volume` Secret volume (data key
  `credentials.json`) and matching `volumeMounts` entry at `/app/credentials.json` to the `$cfg`
  dict's `volumes`/`volumeMounts` keys.
  check: helm unittest src/groundx -f 'tests/layout-ocr-secret_test.yaml'
- [x] 5.2 Mirror the two changed files from 5.1 into `helm/` byte-for-byte.
  check: diff src/groundx/values.schema.json helm/values.schema.json && diff src/groundx/templates/_helpers/app/layout-ocr.tpl helm/templates/_helpers/app/layout-ocr.tpl && grep -q 'layout-ocr-secret' helm/templates/_helpers/app/layout-ocr.tpl

## 6. Chart-wide validation

- [x] 6.1 Run the full local test suite (all families plus the pre-existing suites) and confirm
  every test passes, not only the five new files.
  check: helm unittest src/groundx
- [x] 6.2 Lint and render-check both chart surfaces (`helm lint src/groundx && helm lint helm &&
  helm template src/groundx -f src/groundx/values/minikube/values.yaml > /dev/null`).
  check: n/a — always-green structural CI-parity gate, not a feature assertion; not RED-able at baseline, run manually before the PR
- [x] 6.3 Confirm `helm/` and `src/groundx/` stayed in sync everywhere, not only in the files this
  change touched (catches an accidental one-sided edit anywhere in the tree, via `diff -rq
  src/groundx/templates helm/templates && diff src/groundx/values.schema.json
  helm/values.schema.json`).
  check: n/a — regression guard, true both before and after this change by construction (each family's own 1.2/2.2/3.2/4.3/5.2 sync task proves the new content itself); not RED-able, run manually before the PR

<!--
No DB-migration tasks in this change (chart/values surface only, no schema or seed data).
No cross-service coordination — this change is single-repo (INDEPENDENT role, no contract.md).
-->
