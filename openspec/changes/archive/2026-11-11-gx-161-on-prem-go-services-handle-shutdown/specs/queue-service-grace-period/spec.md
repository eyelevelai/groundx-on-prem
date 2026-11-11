## MODIFIED Requirements

### Requirement: Chart renders a k8s termination grace period from `replicas.gracePeriod`

The chart SHALL render `terminationGracePeriodSeconds` on the Deployment of every Go service the chart can deploy (`groundx`, `layoutWebhook`, `fileAccess`, `metrics`, `preProcess`, `process`, `queue`, `summaryClient`, `upload`, and the opt-in `largeFileDeliver` and `postProcess`). The value SHALL be that service's own `gracePeriod` when set (`<service>.replicas.gracePeriod`; `fileAccess.gracePeriod` for File Access, whose `replicas` stays an integer) and the service's default from the single default table otherwise.

Polarity: **accept and enqueue** — a configured `gracePeriod` must reach the rendered field unchanged and an unset one must render the table default; the opposite outcome (the field absent, or a value taken from another service) must not happen.

#### Scenario: Operator sets gracePeriod on one queue service

- **GIVEN** `summaryClient.replicas.gracePeriod: 600` and no other service sets `gracePeriod`
- **WHEN** `templates/app/golang.yaml` renders every Go Deployment
- **THEN** `summary-client` renders `terminationGracePeriodSeconds: 600`
- **AND** every other Go Deployment renders its own default.

#### Scenario: Operator sets gracePeriod on each of the four request-serving services

- **GIVEN** `groundx.replicas.gracePeriod: 300`, `layoutWebhook.replicas.gracePeriod: 60`, `metrics.replicas.gracePeriod: 90` and `fileAccess.gracePeriod: 100` are each set independently
- **WHEN** `templates/app/golang.yaml` and `templates/app/metrics.yaml` render
- **THEN** each Deployment renders its own configured value and no service picks up a value from another
- **AND** `fileAccess.replicas` still sets `spec.replicas` as an integer.

#### Scenario: Operator sets gracePeriod on the two opt-in queue services

- **GIVEN** `largeFileDeliver.replicas.gracePeriod: 120` and `postProcess.replicas.gracePeriod: 200` with both services enabled
- **WHEN** `templates/app/golang.yaml` renders
- **THEN** `large-file-delivery` renders `120` and `post-process` renders `200`, and neither changes the other or any of the other nine Go Deployments.

### Requirement: Chart renders a derived `drainSeconds` application config value

The chart SHALL render `drainSeconds` = `gracePeriod − 30` seconds (floored at `1`) in the `config.yaml` block of every Go service: `groundxServer`, `layoutWebhookServer`, `metricsServer`, `fileAccessServer`, `preProcessFileServer`, `processFileServer`, `queueFileServer`, `summaryServer`, `uploadFileServer`, `largeFileDeliveryServer` and `postProcessFileServer`. The `gracePeriod` read SHALL be the same effective value the service's pod renders, so a pod and its own block never disagree. Blocks that have `baseURL` carry `drainSeconds` directly after it; `fileAccessServer`, `largeFileDeliveryServer` and `postProcessFileServer` carry it as their first key.

Polarity: **accept and enqueue** — a configured or defaulted `gracePeriod` must produce the correctly derived `drainSeconds` in that exact service's block; the opposite outcome (missing, mis-derived, or leaking into another block) must not happen.

#### Scenario: Default render gives every Go service the table value

- **GIVEN** no `gracePeriod` is set anywhere and `largeFileDeliver`, `postProcess` and `fileAccess` are enabled
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** the seven queue blocks contain `drainSeconds: 870`
- **AND** `groundxServer`, `layoutWebhookServer`, `metricsServer` and `fileAccessServer` contain `drainSeconds: 120`.

#### Scenario: Operator sets gracePeriod on one service only

- **GIVEN** `summaryClient.replicas.gracePeriod: 600` and nothing else is set
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** `summaryServer` contains `drainSeconds: 570`
- **AND** every other block keeps its default.

#### Scenario: gracePeriod below the 30-second margin floors at 1

- **GIVEN** `groundx.replicas.gracePeriod: 20`
- **WHEN** `templates/resources/config-yaml.yaml` renders
- **THEN** `groundxServer` contains `drainSeconds: 1`, not a negative number.

### Requirement: Schema accepts `gracePeriod` as an optional integer ≥ 1, strict otherwise

`src/groundx/values.schema.json` SHALL accept `gracePeriod` (`type: integer`, `minimum: 1`) in the `replicas` block of `summaryClient`, `process`, `upload`, `queue`, `preProcess`, `groundx`, `layoutWebhook`, `metrics`, `largeFileDeliver` and `postProcess`, and as a new top-level `fileAccess.gracePeriod`. Every `replicas` block SHALL keep `additionalProperties: false`, and `fileAccess.replicas` SHALL stay an integer.

Polarity: **reject before state** — an invalid `gracePeriod` (wrong type, or below `1`) or an unknown `replicas` key must fail schema validation before any template renders.

#### Scenario: Schema accepts a valid gracePeriod on each Go service

- **GIVEN** values set a valid integer `gracePeriod` on a service (for example `groundx.replicas.gracePeriod: 300`, `fileAccess.gracePeriod: 100`)
- **WHEN** Helm validates the values against `values.schema.json`
- **THEN** validation succeeds.

#### Scenario: Schema rejects a non-integer gracePeriod

- **GIVEN** values set `gracePeriod: "soon"` on `groundx.replicas`, `postProcess.replicas` or `fileAccess`
- **WHEN** Helm validates the values
- **THEN** validation fails because `gracePeriod` must be an integer.

#### Scenario: Schema rejects a non-positive gracePeriod

- **GIVEN** values set `gracePeriod: 0` on `layoutWebhook.replicas`, `metrics.replicas`, `largeFileDeliver.replicas` or `fileAccess`
- **WHEN** Helm validates the values
- **THEN** validation fails because `gracePeriod` must satisfy `minimum: 1`.

#### Scenario: Schema rejects an unknown replicas key and an object under fileAccess.replicas

- **GIVEN** values set `summaryClient.replicas.timeoutSeconds: 30`, or `fileAccess.replicas: {gracePeriod: 100}`
- **WHEN** Helm validates the values
- **THEN** validation fails because `additionalProperties: false` rejects the key, or because `fileAccess.replicas` must be an integer.

### Requirement: Chart-side rendering is safe to deploy in any order relative to cashbot-go

The chart SHALL be safe to roll out independently of the cashbot-go image's deployment order for the four request-serving services, because the `drainSeconds` key is additive (an image that does not read it ignores it, and an absent key means no drain wait). Two rollouts behave differently and the release note SHALL state both: a new cashbot-go image with an old chart (no `drainSeconds`) makes File Access exit with no wait, and `largeFileDeliver` and `postProcess` start draining for up to 870 seconds as soon as the new chart lands on any image that already supports queue-server drain.

#### Scenario: Backward compatibility — chart ahead of an older image on a request-serving service

- **GIVEN** the chart renders `drainSeconds: 120` for `groundxServer`
- **AND** the running `groundx` image predates the cashbot-go shutdown change and does not read it
- **WHEN** the pod restarts and reads the rendered config
- **THEN** the non-strict YAML decode ignores the key and the pod exits on SIGTERM as before, with no rendering error and no schema failure.

#### Scenario: New image with an old chart leaves File Access without a drain wait

- **GIVEN** a chart that renders no `drainSeconds` in `fileAccessServer`
- **WHEN** a File Access pod on a new image receives SIGTERM
- **THEN** it exits with no wait, which `docs/upgrades.md` states as the expected result.

#### Scenario: Release note states the opt-in queue behavior change

- **GIVEN** `docs/upgrades.md` after this change
- **WHEN** an operator reads the release note
- **THEN** it says every Go Deployment restarts once, and that `largeFileDeliver` and `postProcess` start draining up to 870 seconds as soon as the chart lands.

### Requirement: `src/groundx` and `helm/` mirror render identically

The `helm/` mirror SHALL render identically to `src/groundx` for every template, `values.yaml` and `values.schema.json` this change touches, for the default case and for the `gracePeriod`-set case. `helm/` carries no `tests/` tree, so the drift check (`.build/bin/verify-storage-contract.py`) covers `templates/`, `values.yaml` and `values.schema.json` only, and tests and snapshots are authored in `src/groundx/tests/` alone.

Polarity: **finalize success** — the change is not complete until both chart copies agree; divergence must block completion.

#### Scenario: Mirror files are byte-identical

- **GIVEN** the templates, `values.yaml` and `values.schema.json` under `src/groundx` have been edited for this change
- **WHEN** the same paths under `helm/` are compared
- **THEN** `diff -r src/groundx/templates helm/templates` is empty and both values files compare equal.

#### Scenario: Mirror renders identically with defaults and with overrides

- **GIVEN** the same values, once with no `gracePeriod` and once with a `gracePeriod` set on a request-serving and a queue service
- **WHEN** `helm template` renders `src/groundx` and `helm/`
- **THEN** the two renders are identical.

## ADDED Requirements

### Requirement: One default table and one formula serve every Go service

The chart SHALL hold the per-service default grace period in exactly one place and the `max 1 (sub grace 30)` formula in exactly one place, in a helper that follows the `groundx.celeryWorker.gracePeriod` / `stopWaitSecs` pattern. The table SHALL give `900` to `preProcess`, `process`, `queue`, `summaryClient`, `upload`, `largeFileDeliver` and `postProcess`, and `150` to `groundx`, `layoutWebhook`, `fileAccess` and `metrics`. Pods and config blocks SHALL read the helper; no template, helper or values file SHALL carry another copy of a default or of the subtraction. The helper SHALL NOT write into `.Values`.

Invariant (see design.md `## Decisions`): a Go service's rendered `terminationGracePeriodSeconds` and `drainSeconds` come only from that service's own `gracePeriod` when set, otherwise from its single table entry, with the `− 30` floor applied in one place; they never take another service's value or a second copy of the table.

Polarity: **skip unrelated repair path** — a default or override applied for one service must not reach any other.

#### Scenario: The table and formula each appear once

- **GIVEN** the chart templates after this change
- **WHEN** they are searched for `max 1 (sub` outside `celery-worker.tpl` and for `set $in "gracePeriod" 900`
- **THEN** the subtraction appears once, in the Go grace helper, and no `set $in "gracePeriod" 900` remains in any of the five queue helpers.

#### Scenario: catches — a default added only in the shared `golang.yaml` loop

- **GIVEN** an implementation that renders `terminationGracePeriodSeconds` from a single literal in `templates/app/golang.yaml`
- **WHEN** the default render is checked
- **THEN** `groundx`, `layout-webhook` and `file-access` rendering `900` instead of `150` is a defect, because the table gives them their own entry.

#### Scenario: catches — one service's override leaks into a sibling

- **GIVEN** only `preProcess.replicas.gracePeriod: 120` is set
- **WHEN** the Go Deployments and `config.yaml` render
- **THEN** `pre-process` renders `120` and `preProcessFileServer` renders `drainSeconds: 90`
- **AND** a `120` or `90` on any other pod or block is a sweep-consistency defect.

#### Scenario: must not block — an override and defaults coexist across all eleven services

- **GIVEN** distinct `gracePeriod` values on `groundx`, `layoutWebhook`, `metrics`, `fileAccess`, `largeFileDeliver` and `postProcess`, and none on the five original queue services
- **WHEN** the chart renders
- **THEN** rendering succeeds, each overridden service shows its own value and derived `drainSeconds`, and the five queue services render `900` and `870`.

#### Scenario: The five original queue services render as on 0.3.0 except config-hash

- **GIVEN** a default render on the `0.3.0` baseline and on this change
- **WHEN** the `pre-process`, `process`, `queue`, `summary-client` and `upload` Deployments and their five config blocks are compared
- **THEN** they are identical except the `config-hash` annotation.

## REMOVED Requirements

### Requirement: Sweep consistency across the five parallel `config-yaml.yaml` edits

**Reason:** The five separately authored `drainSeconds` stanzas and the five helpers that each set `gracePeriod` to `900` are replaced by one helper that every Go service reads; the invariant and its catches and must-not-block scenarios now live in "One default table and one formula serve every Go service".

**Migration:** No operator action. Any `<service>.replicas.gracePeriod` override keeps its meaning; the five blocks render the same `drainSeconds` as before.

### Requirement: No gracePeriod set — the five Go queue services default to a 900-second grace period

**Reason:** Every Go service now has a default (900 for seven services, 150 for four), so the rules that every other Deployment "keeps rendering no `terminationGracePeriodSeconds`" and that `config-yaml.yaml` carries "exactly five `drainSeconds` keys" no longer hold.

**Migration:** The 900/870 default for the five original queue services is unchanged and is asserted under "Chart renders a k8s termination grace period from `replicas.gracePeriod`" and "One default table and one formula serve every Go service". The four request-serving services and the two opt-in queue services now render their own default.
