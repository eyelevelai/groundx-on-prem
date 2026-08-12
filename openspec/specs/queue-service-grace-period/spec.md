# queue-service-grace-period Specification

## Purpose
TBD - created by archiving change fra-114-summary-client-hpa-scale-down-interrupts-in-flight-large. Update Purpose after archive.
## Requirements
### Requirement: Chart renders a k8s termination grace period from `replicas.gracePeriod`

The chart SHALL render `terminationGracePeriodSeconds` on each of the five Go queue-service pods' (`summaryClient`/`process`/`upload`/`queue`/`preProcess`) Deployment from that service's own `replicas.gracePeriod` value, guarded by presence (`hasKey`) of that key.

Polarity: **accept and enqueue** — a configured `gracePeriod` must flow through to the
rendered field unchanged; the opposite outcome (the field stays absent, or renders a
different value, despite `gracePeriod` being set) must not happen.

#### Scenario: Operator sets gracePeriod on summaryClient

- **GIVEN** `summaryClient.replicas.gracePeriod: 900`
- **WHEN** `templates/app/golang.yaml` renders the `summaryClient` Deployment
- **THEN** `spec.template.spec.terminationGracePeriodSeconds` equals `900`.

#### Scenario: Operator sets gracePeriod on each of the other four Go queue services

- **GIVEN** `process.replicas.gracePeriod: 300`, `upload.replicas.gracePeriod: 180`,
  `queue.replicas.gracePeriod: 60`, and `preProcess.replicas.gracePeriod: 45` are each set
  independently (no other service's `gracePeriod` set)
- **WHEN** `templates/app/golang.yaml` renders each service's Deployment
- **THEN** each Deployment's `spec.template.spec.terminationGracePeriodSeconds` equals that
  service's own configured value, and no service picks up a value from any other service.

### Requirement: Chart renders a derived `drainSeconds` application config value

The chart SHALL render `drainSeconds` = `gracePeriod − 30` seconds (floored at a minimum of `1`) for each of the five Go queue-service config blocks in `config-yaml.yaml` (`preProcessFileServer`/`processFileServer`/`queueFileServer`/`summaryServer`/`uploadFileServer`), at the same YAML level as that block's existing `baseURL`/`maxConcurrent`/`port`/`serviceName` keys, guarded by presence of that service's own `replicas.gracePeriod`.

Polarity: **accept and enqueue** — a configured `gracePeriod` must produce a correctly
derived `drainSeconds` in that exact service's block; the opposite outcome (missing,
mis-derived, or leaking into a different service's block) must not happen.

#### Scenario: Operator sets gracePeriod on summaryClient only

- **GIVEN** `summaryClient.replicas.gracePeriod: 900` and no other Go queue service sets
  `gracePeriod`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `summaryServer` block contains `drainSeconds: 870`
- **AND** the `preProcessFileServer`, `processFileServer`, `queueFileServer`, and
  `uploadFileServer` blocks do NOT contain a `drainSeconds` key.

#### Scenario: Operator sets gracePeriod independently on all five services

- **GIVEN** each of `preProcess`/`process`/`queue`/`summaryClient`/`upload` sets its own
  distinct `replicas.gracePeriod`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** each of the five blocks (`preProcessFileServer`/`processFileServer`/
  `queueFileServer`/`summaryServer`/`uploadFileServer`) contains its own correctly derived
  `drainSeconds` (that service's `gracePeriod − 30`, min `1`), independent of the other four.

#### Scenario: gracePeriod below the 30-second margin floors at 1

- **GIVEN** `summaryClient.replicas.gracePeriod: 10`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the `summaryServer` block contains `drainSeconds: 1` (not a negative number).

### Requirement: No gracePeriod set — chart output stays byte-identical to today

Neither `terminationGracePeriodSeconds` nor `drainSeconds` SHALL render for a Go queue service whose values do not set `replicas.gracePeriod`, and the rendered Deployment and `config-yaml.yaml` ConfigMap for that service SHALL be byte-identical to their pre-change output.

Polarity: **reject before state** — the absence of `gracePeriod` must create no new
rendered state (no field appears with any value, including a zero or empty string); this
is the no-op-by-default guarantee for every current install and every one of the ~20
`golang.yaml` services that never sets `gracePeriod`.

#### Scenario: Existing service with no gracePeriod renders unchanged

- **GIVEN** a Go queue service's `replicas` block does not include `gracePeriod` (today's
  state for every current install)
- **WHEN** `templates/app/golang.yaml` and `templates/resources/config-yaml.yaml` render
- **THEN** neither `terminationGracePeriodSeconds` nor `drainSeconds` appears anywhere in
  that service's rendered output
- **AND** the `helm-unittest` snapshot for that fixture is unchanged from before this
  change (a snapshot diff on any no-gracePeriod fixture is a regression).

#### Scenario: A non-Go golang.yaml-adjacent service is unaffected

- **GIVEN** a shared `golang.yaml` service other than the five Go queue services (if any
  renders through the same template) has no `gracePeriod` key
- **WHEN** `templates/app/golang.yaml` renders
- **THEN** that service's Deployment is unaffected — the guard is presence-based, not
  service-name-based, so it applies uniformly and safely to every service the shared
  template loops over.

### Requirement: Schema accepts `gracePeriod` as an optional integer, strict otherwise

`src/groundx/values.schema.json` SHALL add `gracePeriod` (`type: integer`) to the `replicas` schema block of all five Go queue-service entries (`summaryClient`/`process`/`upload`/`queue`/`preProcess`), preserving `additionalProperties: false` on each `replicas` block.

Polarity: **reject before state** — an invalid `gracePeriod` (wrong type) or an unknown
`replicas` key must fail schema validation before any values are accepted; validation
failure creates no chart state.

#### Scenario: Schema accepts a valid integer gracePeriod

- **GIVEN** values set `summaryClient.replicas.gracePeriod: 900`
- **WHEN** Helm validates the chart values against `values.schema.json`
- **THEN** validation succeeds.

#### Scenario: Schema rejects a non-integer gracePeriod

- **GIVEN** values set `summaryClient.replicas.gracePeriod: "soon"`
- **WHEN** Helm validates the chart values against `values.schema.json`
- **THEN** validation fails because `gracePeriod` must be an integer.

#### Scenario: Schema rejects an unknown key on a Go queue-service replicas block

- **GIVEN** values set an undefined key, e.g. `summaryClient.replicas.timeoutSeconds: 30`
- **WHEN** Helm validates the chart values against `values.schema.json`
- **THEN** validation fails because `additionalProperties: false` rejects the unknown key.

### Requirement: Chart-side rendering is safe to deploy in any order relative to cashbot-go

The chart SHALL be safe to roll out this change independently of the cashbot-go image's deployment order — an install may upgrade this chart before, after, or in the same rollout as the paired cashbot-go image — because the `drainSeconds-config` touchpoint is Additive (unset/`0` on the cashbot-go side preserves today's immediate-exit behavior).

#### Scenario: Backward compatibility — chart change rolls out ahead of a paired cashbot-go image

- **GIVEN** an install upgrades this chart to render `drainSeconds` for `summaryClient`
  (because it has set `summaryClient.replicas.gracePeriod`)
- **AND** the currently-running `summaryClient` image predates the cashbot-go drain feature
  (so it does not read or act on `drainSeconds`)
- **WHEN** the pod restarts and reads the rendered config
- **THEN** the old binary's non-strict YAML decode ignores the unrecognized `drainSeconds`
  key and it continues its existing immediate-exit-on-SIGTERM behavior — no rendering error,
  no crash, no schema-validation failure on the chart side.

### Requirement: `src/groundx` and `helm/` mirror render identically

The `helm/` published-chart mirror SHALL render identically to its `src/groundx/` counterpart, for both the no-op case and the `gracePeriod`-set case, for the three touched files (`values.schema.json`, `templates/app/golang.yaml`, `templates/resources/config-yaml.yaml`).

Polarity: **finalize success** — this proposal is not complete until both chart copies
agree; the opposite outcome (the two copies diverge on either file) must not happen and
must block completion.

#### Scenario: Mirror diff is empty for the touched files

- **GIVEN** `src/groundx/values.schema.json`, `src/groundx/templates/app/golang.yaml`, and
  `src/groundx/templates/resources/config-yaml.yaml` have been edited for this change
- **WHEN** the matching files under `helm/` are compared with `diff`
- **THEN** the diff is empty for all three file pairs.

#### Scenario: Mirror renders identically with gracePeriod set

- **GIVEN** the same values setting `summaryClient.replicas.gracePeriod: 900`
- **WHEN** `helm template` renders `src/groundx` and `helm template` renders `helm/`
- **THEN** the rendered `summaryClient` Deployment and `config-yaml.yaml` ConfigMap are
  identical between the two chart copies.

### Requirement: Sweep consistency across the five parallel `config-yaml.yaml` edits

Each block's `drainSeconds` render SHALL be gated on that exact block's own service replicas dict — never a value copied from, or shared with, a different block — because `config-yaml.yaml` renders its five Go queue-service blocks as five separately authored literal stanzas rather than through a shared loop.

Invariant (see design.md `## Decisions`): a service's rendered grace-period-derived fields
may differ from today's output only when that exact service's own `replicas.gracePeriod`
is present — never when a different service sets it, and never for a service that leaves
it unset.

#### Scenario: catches — setting gracePeriod on one service must not leak into a sibling block

- **GIVEN** only `preProcess.replicas.gracePeriod: 120` is set (the other four services
  leave `gracePeriod` unset)
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** only the `preProcessFileServer` block contains `drainSeconds`
- **AND** the `processFileServer`, `queueFileServer`, `summaryServer`, and
  `uploadFileServer` blocks contain no `drainSeconds` key — a rendered `drainSeconds` in
  any of those four blocks is a sweep-consistency defect, not the intended behavior.

#### Scenario: must not block — five independently-configured services all render correctly

- **GIVEN** all five services set distinct `replicas.gracePeriod` values (as in the
  "Operator sets gracePeriod independently on all five services" scenario above)
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** rendering succeeds and every one of the five blocks contains its own correct
  `drainSeconds` — an implementation that only wires up the first block it touched (e.g.
  `summaryServer`) and silently leaves the other four unrendered fails this scenario.

