## RENAMED Requirements

- FROM: `### Requirement: No gracePeriod set — chart output stays byte-identical to today`
- TO: `### Requirement: No gracePeriod set — the five Go queue services default to a 900-second grace period`

## MODIFIED Requirements

### Requirement: No gracePeriod set — the five Go queue services default to a 900-second grace period

When a Go queue service (`preProcess`/`process`/`queue`/`summaryClient`/`upload`) does not set `replicas.gracePeriod`, the chart SHALL render `terminationGracePeriodSeconds: 900` on that service's Deployment and `drainSeconds: 870` in that service's `config-yaml.yaml` block. The default SHALL come from that service's own `groundx.<service>.replicas` helper, so the unchanged presence guards in `templates/app/golang.yaml` and `templates/resources/config-yaml.yaml` render it. Every other Deployment rendered by `templates/app/golang.yaml` (`groundx`, `layoutWebhook` and the opt-in `fileAccess`/`largeFileDeliver`/`postProcess` workers) SHALL keep rendering no `terminationGracePeriodSeconds`, and its config block SHALL render no `drainSeconds`.

Polarity: **accept and enqueue** — an unset `gracePeriod` on one of the five services must produce the 900/870 default; the opposite outcome (the field stays absent, or renders any other value, while the service sets nothing) must not happen. **Skip unrelated repair path** — a service that is not one of the five must not pick up the default.

#### Scenario: Unset gracePeriod renders the default on each of the five services

- **GIVEN** none of `preProcess`/`process`/`queue`/`summaryClient`/`upload` sets `replicas.gracePeriod`
- **WHEN** `templates/app/golang.yaml` and `templates/resources/config-yaml.yaml` render
- **THEN** the `pre-process`, `process`, `queue`, `summary-client` and `upload` Deployments each render `spec.template.spec.terminationGracePeriodSeconds` equal to `900`
- **AND** the `preProcessFileServer`, `processFileServer`, `queueFileServer`, `summaryServer` and `uploadFileServer` blocks each contain `drainSeconds: 870`.

#### Scenario: Services outside the five render no grace period

- **GIVEN** no `gracePeriod` is set anywhere
- **WHEN** `templates/app/golang.yaml` renders the `groundx` and `layout-webhook` Deployments
- **THEN** neither Deployment contains `terminationGracePeriodSeconds`
- **AND** `config-yaml.yaml` contains exactly five `drainSeconds` keys, one in each of the five service blocks above.

#### Scenario: catches — a default applied in the shared template reaches a service outside the five

- **GIVEN** an implementation that adds the 900-second default as an `else` branch in `templates/app/golang.yaml`, which loops over every Go service
- **WHEN** `templates/app/golang.yaml` renders the `groundx` and `layout-webhook` Deployments with no `gracePeriod` set
- **THEN** a `terminationGracePeriodSeconds` on either of them is a defect, because the invariant limits the default to the five services whose helpers carry it.

#### Scenario: must not block — an explicit gracePeriod overrides the default for its own service only

- **GIVEN** `process.replicas.gracePeriod: 120` and no other service sets `gracePeriod`
- **WHEN** `templates/app/golang.yaml` and `templates/resources/config-yaml.yaml` render
- **THEN** the `process` Deployment renders `terminationGracePeriodSeconds: 120` and the `processFileServer` block renders `drainSeconds: 90`
- **AND** the `pre-process`, `queue`, `summary-client` and `upload` Deployments render `900` and their blocks render `drainSeconds: 870`.

#### Scenario: The helm/ mirror renders the default identically

- **GIVEN** the five helper files under `src/groundx/templates/_helpers/app/` carry the default
- **WHEN** `helm template` renders `src/groundx` and `helm/` with no `gracePeriod` set
- **THEN** the five Deployments and the `config-yaml.yaml` Secret are identical between the two chart copies
- **AND** `diff -r src/groundx/templates helm/templates` is empty.

#### Scenario: Backward compatibility — an image that predates the cashbot-go drain feature

- **GIVEN** an install upgrades to a chart that renders the 900/870 default
- **AND** the running `process` image predates the cashbot-go drain feature and does not read `drainSeconds`
- **WHEN** the pod restarts and reads the rendered config
- **THEN** the non-strict YAML decode ignores the unrecognized `drainSeconds` key and the pod exits on SIGTERM as before, with no rendering error and no schema-validation failure.

### Requirement: Chart renders a derived `drainSeconds` application config value

The chart SHALL render `drainSeconds` = `gracePeriod − 30` seconds (floored at a minimum of `1`) for each of the five Go queue-service config blocks in `config-yaml.yaml` (`preProcessFileServer`/`processFileServer`/`queueFileServer`/`summaryServer`/`uploadFileServer`), at the same YAML level as that block's existing `baseURL`/`maxConcurrent`/`port`/`serviceName` keys. The `gracePeriod` read is that service's own `replicas.gracePeriod`, which is `900` when the operator does not set it, so every one of the five blocks renders a `drainSeconds`.

Polarity: **accept and enqueue** — a configured or defaulted `gracePeriod` must produce a correctly derived `drainSeconds` in that exact service's block; the opposite outcome (missing, mis-derived, or leaking into a different service's block) must not happen.

#### Scenario: Operator sets gracePeriod on summaryClient only

- **GIVEN** `summaryClient.replicas.gracePeriod: 600` and no other Go queue service sets `gracePeriod`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `summaryServer` block contains `drainSeconds: 570`
- **AND** the `preProcessFileServer`, `processFileServer`, `queueFileServer` and `uploadFileServer` blocks each contain `drainSeconds: 870`.

#### Scenario: Operator sets gracePeriod independently on all five services

- **GIVEN** each of `preProcess`/`process`/`queue`/`summaryClient`/`upload` sets its own distinct `replicas.gracePeriod`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** each of the five blocks (`preProcessFileServer`/`processFileServer`/`queueFileServer`/`summaryServer`/`uploadFileServer`) contains its own correctly derived `drainSeconds` (that service's `gracePeriod − 30`, min `1`), independent of the other four.

#### Scenario: gracePeriod below the 30-second margin floors at 1

- **GIVEN** `summaryClient.replicas.gracePeriod: 10`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `summaryServer` block contains `drainSeconds: 1` (not a negative number).

### Requirement: Sweep consistency across the five parallel `config-yaml.yaml` edits

Each block's `drainSeconds` render SHALL be gated on that exact block's own service replicas dict — never a value copied from, or shared with, a different block — because `config-yaml.yaml` renders its five Go queue-service blocks as five separately authored literal stanzas rather than through a shared loop. The same applies to the default: each of the five `groundx.<service>.replicas` helpers SHALL set `gracePeriod` to `900` on its own service's replicas dict only when that dict has no `gracePeriod` key.

Invariant (see design.md `## Decisions`): a service's rendered grace-period fields equal its own explicit `replicas.gracePeriod` when it sets one and the 900/870 default when it does not, for each of the five services alike; they never take another service's value, and a service outside the five never renders them.

#### Scenario: catches — a sweep that defaults only some of the five helpers

- **GIVEN** no `gracePeriod` is set anywhere
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** all five of the `preProcessFileServer`, `processFileServer`, `queueFileServer`, `summaryServer` and `uploadFileServer` blocks contain `drainSeconds: 870` — a block with no `drainSeconds` means that service's helper was missed by the sweep and is a sweep-consistency defect.

#### Scenario: catches — setting gracePeriod on one service must not leak into a sibling block

- **GIVEN** only `preProcess.replicas.gracePeriod: 120` is set
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `preProcessFileServer` block contains `drainSeconds: 90`
- **AND** the `processFileServer`, `queueFileServer`, `summaryServer` and `uploadFileServer` blocks each contain `drainSeconds: 870` — a `90` in any of those four blocks is a sweep-consistency defect.

#### Scenario: must not block — five independently-configured services all render correctly

- **GIVEN** all five services set distinct `replicas.gracePeriod` values (as in the "Operator sets gracePeriod independently on all five services" scenario above)
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** rendering succeeds and every one of the five blocks contains its own correct `drainSeconds`, and none of them renders the 870 default.
