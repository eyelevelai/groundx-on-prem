## ADDED Requirements

### Requirement: OpenSearch credentials support a Secret-backed path
The chart SHALL accept a `search.existingSecret` boolean. When `true`, the `groundx` pod SHALL
receive `SEARCH_USERNAME`, `SEARCH_PASSWORD`, `SEARCH_PRIVILEGED_USERNAME`, and
`SEARCH_PRIVILEGED_PASSWORD` via `envFrom` referencing a pre-existing Secret named
`opensearch-secret` that the chart does not create. Each of `search.username`, `search.password`,
`search.privilegedUsername`, `search.privilegedPassword` that is non-empty SHALL still render as a
plaintext literal in `config-yaml.yaml` (config wins); each that is empty SHALL be omitted from
`config-yaml.yaml` entirely, never rendered as an empty string. `search.existingSecret` defaulting
to unset/false SHALL leave `config-yaml.yaml` and the Secret set byte-identical to chart behavior
before this change (polarity: **reject before state** — no Secret resource is fabricated from the
chart's own non-empty default credentials).

#### Scenario: Secret path — plaintext empty, existingSecret set
- **WHEN** `search.existingSecret=true` and `search.password=""` (and the other three OpenSearch
  fields likewise empty)
- **THEN** `helm template` renders `SEARCH_USERNAME`/`SEARCH_PASSWORD`/
  `SEARCH_PRIVILEGED_USERNAME`/`SEARCH_PRIVILEGED_PASSWORD` in the `groundx` Deployment's
  `envFrom` referencing Secret `opensearch-secret`, **and** the `password`/`username` keys are
  absent from the rendered `config-yaml.yaml` `ai.aws.search` and `init.search` blocks

#### Scenario: Catches — config wins even when existingSecret is set (polarity: finalize success only on the winning source)
- **WHEN** `search.existingSecret=true` **and** `search.password` is also set to a non-empty
  plaintext value
- **THEN** the plaintext `password` line still renders in `config-yaml.yaml` (config wins over the
  Secret path) — the renderer MUST NOT suppress a non-empty plaintext value just because
  `existingSecret` is set

#### Scenario: Must not block — default install renders unchanged (polarity: reject before state)
- **WHEN** `search.existingSecret` is left unset (chart defaults only)
- **THEN** no `opensearch-secret` Secret resource is rendered anywhere in the chart's output, and
  `groundx`'s `envFrom` list contains no `SEARCH_*` entries — the feature is fully inert until
  explicitly opted into

### Requirement: Summary API key supports a Secret-backed path mirroring extract.agent
The chart SHALL accept a `summary.existing.existingSecret` boolean, mirroring the existing
`extract.agent.existingSecret` pattern exactly. When `summary.existing.apiKey` is non-empty and
`existingSecret` is unset/false, the chart SHALL create a Secret carrying `GROUNDX_SUMMARY_API_KEY`
from that value and wire it via `envFrom` into the `groundx` pod. When `existingSecret=true`, the
chart SHALL instead reference a pre-existing Secret named `summary-secret` (not create one) via the
same `envFrom` entry. `ai.openai.apiKey` in `config-yaml.yaml` SHALL continue to render only when
non-empty (already the case before this change) and is unaffected by `existingSecret`.

#### Scenario: Secret path — apiKey empty, existingSecret set
- **WHEN** `summary.existing.existingSecret=true` and `summary.existing.apiKey` is unset
- **THEN** the `groundx` Deployment's `envFrom` includes a `secretRef` to `summary-secret`, and no
  Secret named `summary-secret` is created by the chart itself

#### Scenario: Plaintext path — apiKey set, existingSecret unset (dev path, unchanged)
- **WHEN** `summary.existing.apiKey=test-summary-key` and `existingSecret` is unset
- **THEN** `config-yaml.yaml` renders `ai.openai.apiKey: test-summary-key` literally, **and** the
  chart creates a Secret carrying `GROUNDX_SUMMARY_API_KEY=test-summary-key` and wires it via
  `envFrom` into the `groundx` pod (mirrors `extract.agent`'s existing apiKey behavior)

#### Scenario: Must not block — neither set (polarity: reject before state)
- **WHEN** neither `summary.existing.apiKey` nor `existingSecret` is set (chart defaults)
- **THEN** no `ai.openai.apiKey` key renders in `config-yaml.yaml` (already true before this
  change) and no summary-related Secret or `envFrom` entry appears anywhere in the rendered output

### Requirement: Redis AUTH is configurable for an external cache only
The chart SHALL accept `cache.existing.password` (string) and `cache.existing.existingSecret`
(boolean), meaningful only when `cache.existing.addr` (external Redis) is set — the chart-bundled
Redis deployment SHALL remain auth-less and unaffected. When `existingSecret=true`, the chart SHALL
fold a `REDIS_AUTH`-bearing Secret named `redis-secret` (assumed pre-existing, not created by the
chart) into `groundx.secrets`, the existing global secret-injection mechanism already merged via
`envFrom` into every workload pod type (`api.yaml`, `celery.yaml`, `golang.yaml`, `inference.yaml`,
`metrics.yaml`). When `cache.existing.password` is non-empty and `existingSecret` is unset/false,
the chart SHALL create that `redis-secret` Secret from the plaintext value instead of assuming one
exists.

#### Scenario: Secret path — external Redis, password empty, existingSecret set
- **WHEN** `cache.existing.addr=redis.mycorp.net`, `cache.existing.password=""`, and
  `cache.existing.existingSecret=true`
- **THEN** every rendered Deployment's `envFrom` includes a `secretRef` to `redis-secret`, and the
  chart does not render a Secret resource named `redis-secret`

#### Scenario: Plaintext path — external Redis, password set (dev path)
- **WHEN** `cache.existing.addr=redis.mycorp.net` and `cache.existing.password=test-redis-auth`
- **THEN** the chart renders a Secret named `redis-secret` containing `REDIS_AUTH=test-redis-auth`
  and wires it into every workload pod's `envFrom`

#### Scenario: Must not block — bundled Redis stays auth-less (polarity: skip unrelated repair path)
- **WHEN** `cache.existing` is empty (bundled Redis, the default)
- **THEN** no `REDIS_AUTH` Secret, key, or `envFrom` entry renders anywhere, and the bundled Redis
  Deployment/StatefulSet is byte-identical to chart behavior before this change

### Requirement: Application API keys (extract/ranker) support a Secret-backed path
The chart SHALL accept an `admin.existingSecret` boolean. When `admin.apiKey` or `admin.username`
is non-empty and `existingSecret` is unset/false, the chart SHALL create a Secret named
`groundx-admin-secret` carrying `GROUNDX_ADMIN_API_KEY`/`GROUNDX_ADMIN_USERNAME` and wire it via
`envFrom` into every pod that renders `extract-config-py.yaml` (`extract.agent`, `extract.download`,
`extract.save`) or `ranker-config-py.yaml` (`ranker.api`, `ranker.inference`). When
`existingSecret=true`, the chart SHALL instead reference a pre-existing Secret of that name (not
create one). `extract-config-py.yaml`'s `callback_api_key`/`api_key`/`valid_api_keys` and
`ranker-config-py.yaml`'s `validAPIKeys` SHALL continue to render the plaintext literal whenever the
underlying value (`admin.apiKey`/`admin.username`) is non-empty (config wins); when
`existingSecret=true` and the corresponding value is empty, the rendered Python SHALL read the
value from `os.environ.get(...)` instead of omitting the constructor argument.

#### Scenario: Secret path — admin values empty, existingSecret set
- **WHEN** `admin.existingSecret=true` and `admin.apiKey`/`admin.username` are unset
- **THEN** `extract-config-py.yaml` renders `callback_api_key=os.environ.get("GROUNDX_ADMIN_API_KEY", "")`
  (or the equivalent for `admin.username`-sourced fields) instead of a literal empty string, **and**
  `extract.agent`/`extract.download`/`extract.save`/`ranker.api`/`ranker.inference` Deployments'
  `envFrom` reference Secret `groundx-admin-secret`, which the chart does not create

#### Scenario: Catches — plaintext set overrides existingSecret (polarity: finalize success only on the winning source)
- **WHEN** `admin.existingSecret=true` **and** `admin.apiKey=test-admin-key` is also set
- **THEN** `extract-config-py.yaml`/`ranker-config-py.yaml` still render the plaintext literal
  `test-admin-key` (config wins) — the renderer MUST NOT switch to the `os.environ.get(...)` form
  just because `existingSecret` is set

#### Scenario: Must not block — neither set (polarity: reject before state)
- **WHEN** neither `admin.apiKey`/`admin.username` nor `existingSecret` is set
- **THEN** rendering is byte-identical to chart behavior before this change (today's literal empty
  strings / empty list), and no `groundx-admin-secret` Secret or new `envFrom` entry appears

### Requirement: Google OCR credential supports a Secret-volume path alongside the packaged file
The chart SHALL accept a `layout.ocr.existingSecret` boolean. When `true`, the `layout-ocr` pod
(the only pod that mounts the OCR credential; verified as the sole consumer of
`layout.ocr.credentials`) SHALL mount a Secret volume — assumed pre-existing, not created by the
chart — at `/app/credentials.json` from a Secret named `layout-ocr-secret` with data key
`credentials.json`. The existing packaged-ConfigMap-file path (`layout.ocr.credentials`) SHALL
remain unchanged and continue to work when `existingSecret` is not set. Setting both
`layout.ocr.credentials` and `layout.ocr.existingSecret` simultaneously SHALL fail the render (they
are mutually exclusive — both mount at the same container path) rather than silently mounting one
over the other or producing a duplicate-mountPath manifest.

#### Scenario: Secret-volume path
- **WHEN** `layout.ocr.existingSecret=true` and `layout.ocr.credentials` is unset
- **THEN** the `layout-ocr` Deployment mounts a `credentials-secret-volume` from Secret
  `layout-ocr-secret` (key `credentials.json`) at `/app/credentials.json`, and no
  `layout-ocr-credentials-map` ConfigMap is required

#### Scenario: Packaged-file path unchanged (dev path)
- **WHEN** `layout.ocr.credentials=files/ocr/credentials.json` and `existingSecret` is unset
- **THEN** rendering is unchanged from chart behavior before this change — the ConfigMap-backed
  `credentials-volume` mounts at `/app/credentials.json` exactly as today

#### Scenario: Catches — mutually exclusive inputs must fail closed (polarity: reject before state)
- **WHEN** both `layout.ocr.credentials` and `layout.ocr.existingSecret=true` are set
- **THEN** `helm template`/`helm install` fails with an explicit error naming the conflict, rather
  than rendering two volumes at the same `mountPath`

#### Scenario: Must not block — OCR disabled by default (polarity: skip unrelated repair path)
- **WHEN** neither `layout.ocr.credentials` nor `layout.ocr.existingSecret` is set
- **THEN** no credentials ConfigMap, Secret, or volume mount of either kind renders for
  `layout-ocr`, and the GX-11 `hasOCR` whitespace-chomp conditional in `templates/app/celery.yaml`
  is untouched by this change (verified by an unmodified `git diff` on that file's `-}}` lines)
