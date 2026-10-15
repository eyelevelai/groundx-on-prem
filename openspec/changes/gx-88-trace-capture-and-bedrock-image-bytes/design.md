The motivation and the rollout risk for older images are in `proposal.md`; this document records how the chart change is made and checked.

## Goals / Non-Goals

**Goals:**
- Let the chart render the extract agent with `extract.agent.serviceType: bedrock` on every file storage type (`s3`, `s4`, and the chart's default storage type).
- Keep every other check in `groundx.extract.agent.validateImageSettings` rejecting what it rejected before.
- Commit helm-unittest coverage for Bedrock on non-`s3` storage, for a failing input the helper still rejects, and for the `s4` pass-through the archived S4 change proved only with a render check.

**Non-Goals:**
- Any other template, default, `values.schema.json`, or snapshot change. The chart stays at `0.2.8`.
- README, `AGENTS.md`, or values-comment changes. None of them mentions Bedrock.
- Trace capture, which needs no change in this repo (`proposal.md`, Why).
- Live Bedrock calls. Coverage is by tests only, per the ticket's definition of done.
- The cashbot-go and extract-service changes that send image bytes. They live in those repos.

## Decisions

### 1. Invariant

Removing the Bedrock storage check SHALL change only one outcome: Bedrock with storage other than `s3` now renders, and every other image-setting combination the helper rejected before still fails the render.

The checks are written against that meaning, not against the token "the fail text is gone":
- the catches case is a Bedrock render on non-`s3` storage with an invalid long edge that must still fail;
- the must-not-block cases are Bedrock on the default storage and on `s4` with valid settings, which must render.

A change that deleted the helper's call from `groundx.extract.agent.settings` (`extract-agent.tpl:308`) would remove the fail text and pass the must-not-block cases, but the catches case rejects it. The catches case does not guard the helper's second call, at `templates/resources/extract-config-py.yaml:17`: a change that removed only that call would leave every case green. This design leaves that call unchanged.

### 2. Remove four lines, in both template copies

The removal covers only the `$serviceType` lookup and the `if`/`fail` block at `src/groundx/templates/_helpers/app/extract-agent.tpl:273-276` and the same lines in `helm/templates/_helpers/app/extract-agent.tpl`. The two files were byte-identical at `b67b3ded`, and `verify_mirrors()` in `.build/bin/verify-storage-contract.py` keeps them so on every gate run.

The removed lines are whitespace-trimmed template actions that emit no text. Every input that rendered before should therefore render byte-identically, and the verification task proves this against `b67b3ded` rather than assuming it.

Alternative considered: keep the check and allow `s4` and the default storage type explicitly. Rejected. The ticket says the chart accepts Bedrock with any storage type (Linear GX-88, desired behavior 7), and an allowlist would block the next storage type for no runtime reason.

### 3. Tests stay in the existing suite, assertion-only

All new cases go into `src/groundx/tests/extract_test.yaml` beside their neighbours, with no new suite and no snapshot. That follows the repo's reuse convention (lessons: `small-fix-reuse-tests-not-bespoke-mechanism`, `agent-code-must-find-existing-home`). The cases:
- "bedrock extract config renders with the default storage" and "bedrock extract config renders with s4 storage" replace "bedrock extract config rejects non-S3 storage".
- "bedrock extract config still rejects a minimum long edge above the target" is the catches case. The removed case was the suite's only `failedTemplate` assertion on the helper.
- "s4 storage type reaches cashbot-go, layout, and extract unchanged" renders `config-yaml.yaml`, `layout-config-py.yaml` and `extract-config-py.yaml` with the values of the archived S4 scenario. Each assertion names its template, because the layout and extract Secrets both carry `stringData["config.py"]`.

### 4. The failing input uses the long-edge check, asserted on the first failing template

`values.schema.json` declares:
- `extract.agent.imageTransport` as an enum of `pil`, `data_url` and `remote_url`;
- `maxRequestImages` with `minimum: 1`;
- `jpegQualities` items with `minimum: 1` and `maximum: 95`.

Helm rejects those values at schema validation, before any template runs, so a test of them exercises the schema, not the helper. The long-edge relation ("minLongEdgePx must be less than or equal to targetLongEdgePx") is the only check in the helper that values passing the schema can reach.

Helm stops at the first template that fails. For extract agent settings that is `templates/resources/extract-supervisord-conf.yaml`, through `groundx.extract.agent.settings`. The case therefore asserts against that template. Against `extract-config-py.yaml` it reports "No failed document".

Alternative considered: an `errorPattern` on the schema error for `imageTransport`. Rejected at the escalation of 2026-10-15 (user decision, option B), because it would not exercise the helper.

### 5. The new capability spec avoids the default storage type's literal name

The archived S4 change's MinIO sweep allowlist allows only `object-store-install-and-upgrade` and `s4-storage-type` under `openspec/specs/` (`openspec/changes/archive/2026-10-14-gx-88-migrate-minio-to-s4/design.md`, "MinIO sweep allowlist"). Archiving this change creates `openspec/specs/extract-bedrock-storage/spec.md`.

The new spec therefore names "the chart's default storage type" in prose. The literal `type=` value appears only in `extract_test.yaml`, which is already on that allowlist. Task 1.2 enforces this.

The MODIFIED deltas to the two allowlisted specs can name it freely.

### 6. Compatibility: additive, no contract touchpoint

The workspace contract (`gx-88-migrate-minio-to-s4/contract.md`) has no Bedrock touchpoint. This change only lets inputs that failed to render now render, and it changes no rendered shape for any input that rendered before (decision 2). No compatibility mechanism is needed.

The runtime risk of older pinned images refusing Bedrock on non-`s3` storage, and the rollback to chart 0.2.7, are covered in `proposal.md`, Impact.

### 7. How the checks run without touching the worktree

The Bedrock task's check copies the working tree's `src/groundx` to a `mktemp -d` directory and runs `helm unittest -f tests/extract_test.yaml` there with helm v3.19.0. It never runs bare `helm unittest` in the worktree, because that rewrites snapshot files when the OCR fixture is absent (lesson: `on-prem-bare-helm-unittest-corrupts-snapshots`).

The `s4` pass-through and long-edge cases pass on the unchanged chart. Under the RED baseline they cannot fail on their own, so they ride under the same check, which fails on the unchanged chart because of the two Bedrock render cases.

The verification task runs `.build/bin/validate-helm.sh` with `helm` and `python` resolved through a temporary PATH directory, as the archived S4 change's chart-bump check did. Renders are compared with `cmp` and never printed.

## Risks / Trade-offs

- [The template checks on `imageTransport`, `maxRequestImages` and `jpegQualities` stay untested by helm-unittest, because the schema rejects those inputs first] → The schema is the effective guard for those fields today. No new test can reach them through values without bypassing the schema run-wide.
- [The byte-identity check uses a fixed list of inputs] → It covers the bundled store, the minikube, existing-store and AWS samples, both alternative modes, and the extract sample on `s3` with and without Bedrock. Any other input that rendered before passes through the same helper, whose remaining lines are unchanged.
- [Rollout] → No rendered change and no pod restart for existing installs. The release order is unchanged (`proposal.md`, Impact). No manual operation or secret change is needed.
