The motivation and current state are in `proposal.md`; this file records how the three optional values are built and proven.

## Goals / Non-Goals

**Goals:**
- `cluster.processors` replaces any of the 13 processor ID lists and drives the ingest-mode skip-generate entries.
- `file.publicUrl` sets `upload.baseUrl` and `file.groundxPublicUrl` adds an `uploadGroundx` section, both with the gateway off.
- Omitting every new key renders the same `config.yaml` as the base commit `895ca7a35`; no committed snapshot changes.

**Non-Goals:**
- Changing the default IDs, how cashbot-go resolves processors, or the gateway (`fileAccess.*`) behavior.
- Detecting a processor ID that points at the wrong database row. The chart cannot see the database.
- Changing layout or extract presentation URLs, storage waits, the gateway host check, or any `groundx.file.*` helper that exists today.
- Applying the keys to the GroundX Cloud deployment values, publishing the chart, or bumping the chart version or image tags.

## Decisions

**Invariant (render check).** A rendered config never carries a link host that the running cashbot-go would ignore or fail closed on: with the gateway on, link hosts come only from `fileAccess.*`, and `file.publicUrl` / `file.groundxPublicUrl` take effect only with the gateway off.

### 1. Processor defaults live in one template helper, overlaid by the user's lists
A new `groundx.processors` define beside `groundx.preProcessors` in `templates/_helpers/main.tpl` holds today's 13 defaults as a dict and overlays each list present in `cluster.processors`, then returns the effective map. `config-yaml.yaml` ranges over that map (Go templates iterate map keys in sorted order, which is today's key order) and writes each list as `key: [id, id]`, passing each ID through `int` because Helm hands numeric values over as floats. The ingest-mode block ranges over the effective `skipGenerate` list and writes one `- processorID: <id>` / `type: skip-generate` entry per ID with today's indentation.

- *Alternative: defaults in `values.yaml` (`cluster.processors: {convert: [11], ...}`).* Rejected. An operator values file that sets `cluster.processors: null` or `{}` would delete every default and render an empty map that cashbot-go cannot process, and the defaults would sit in two files that must match. With template-side defaults, `values.yaml` carries only `processors: {}` and a short comment.
- *Alternative: a separate key for the ingest-mode ID.* Rejected. The ticket asks that the entry use the configured `skipGenerate` IDs; a second key could disagree with the first.

Schema: `cluster.processors` is an object with `additionalProperties: false` and 13 optional properties, each `{"type": "array", "items": {"type": "integer"}, "minItems": 1}`. The cluster block already rejects unknown keys, so `processors` must be declared there. A misspelled list name fails validation instead of being ignored.

### 2. `file.publicUrl` replaces only `upload.baseUrl`
In the gateway-off branch of the `upload` section, `baseUrl` renders `file.publicUrl` when it is non-empty and today's `scheme://baseDomain` otherwise. `baseDomain` and `bucketUrl` keep the storage host, because cashbot-go uses `baseDomain` as the storage endpoint for MinIO and S4 and recognizes its own stored links by `baseUrl` or `bucketUrl` (cashbot-go `pkg/utility/url.go:360-394` at `9c12fb5fc3`). For MinIO, cashbot-go appends `/<bucket>` to `baseUrl` (`pkg/config/upload.go` `BaseURL()` at `9c12fb5fc3`), so the link host is a root origin, which the schema pattern already enforces.

Both URL keys are top-level `file.*` strings with default `""` and the schema pattern `^$|^https?://[^/@?#]+$`, the same as `file.signingEndpoint`. They are not under `file.existing`, because `groundx.file.existing` keys on `file.existing.url`; a key there without a URL would change nothing and could mislead, and the keys also apply to chart-deployed MinIO.

### 3. `uploadGroundx` shares `upload`'s storage fields from one define
When `file.groundxPublicUrl` is non-empty, `config-yaml.yaml` renders `uploadGroundx` after `uploadFileServer` (its alphabetical position, at the end of the file): `signingEndpoint` when `file.signingEndpoint` is set, `baseDomain` from the same file settings, `baseUrl` from `file.groundxPublicUrl`, then the storage fields. The storage fields (`bucket`, `bucketUrl`, `id`, `region`, `secret`, `service`, `ssl`, `token`, with today's presence rules) move into one new define in `templates/_helpers/services/file.tpl` that both `upload` and `uploadGroundx` include, so a field added to one section cannot miss the other. The existing `groundx.file.*` helpers are not edited.

- *Alternative: copy the field block into `uploadGroundx`.* Rejected because the two copies would drift silently. The cost of the shared define is that the `upload` rendering code moves; the unchanged snapshots prove its output did not.

The recorded gate run on the implemented change (2026-10-26, `.build/bin/validate-helm.sh` with Helm v3.19.0) passed 23 test suites, 534 tests and 850 snapshots.

### 4. The gateway conflict is a render failure in the existing validate list
Two checks open the enabled branch of `groundx.fileAccess.validate` (`templates/_helpers/app/file-access.tpl`), before the gateway readiness checks, so an operator who turns the gateway on with GroundX Cloud values sees the key conflict first:

- `file.publicUrl is not supported when fileAccess is enabled; remove it and set the file link host with fileAccess.publicUrl`
- `file.groundxPublicUrl is not supported when fileAccess is enabled; a second file link host requires fileAccess.enabled false`

The second message does not mention `fileAccess.trustedOrigins`: trusted origins keep old alias links recognized by the gateway, but they do not replace a second link host, and cashbot-go validates the gateway against `uploadGroundx` whenever its `baseUrl` is set and fails closed otherwise (cashbot-go `pkg/cbdb/file_access.go:174-179` at `324a6fc78c`). No second implementation of the gateway checks is added. The gateway-off path never calls this define, so it is unaffected.

### 5. Tests extend the two existing suites; the default-path oracle is the committed snapshots
Eight cases, no new files and no new values fixtures (test inputs use `set:`):

- `tests/resources_test.yaml`: every list overridden; partial override; ingest mode with `skipGenerate: [4]`; a misspelled list name fails schema validation.
- `tests/file_settings_test.yaml`: link host plus alias with S3 on a third host; link host without alias on MinIO; gateway rejects `file.publicUrl`; gateway rejects `file.groundxPublicUrl`.

Asserts are `matchRegex` / `notMatchRegex` on `stringData["config.yaml"]` with literal expected values, and `failedTemplate`. The oracle is independent of the new helper: the expected strings are written out in the test, and the default path is pinned by the 850 committed snapshots, whose `config.yaml` renders cover the default, ingest, `cluster.preProcessors`, existing-storage and cloud fixtures. The gateway rejection cases assert on `templates/resources/ingress.yaml`, like the existing gateway rejection cases, because that is where Helm reports the validate failure for that fixture.

Verify-time evidence, saved outside the repository and cited in the PR body, not committed as scripts:
- **Mutation proof:** change one default ID in the helper, run the resources suite, confirm the default snapshots fail, restore.
- **Differential render:** render every fixture under `src/groundx/tests/files/` that renders at `07d332fc6c`, at that commit and at the feature tip, and compare only the `processors` mapping, the `upload` mapping, and the absence of `uploadGroundx`, with `yq` on named fields. A difference that comes from a `0.2.8` change made before this branch is rechecked against the base `895ca7a35` render and reported as such. Rendered bodies are never printed.

### 6. Mirror and gate
Every template, `values.yaml` and `values.schema.json` edit is copied byte-for-byte into `helm/`. `verify_mirrors()` in `.build/bin/verify-storage-contract.py` byte-compares the templates tree, and this change adds `values.yaml` and `values.schema.json` to its `MIRRORED_FILES` list, so the gate also fails when either pair drifts. The gate is `.build/bin/validate-helm.sh` with Helm v3.19.0 and a real Python first on `PATH` (it calls bare `helm` and `python`). Never `helm unittest -u`.

No ADR: the change adds three optional values to an existing values contract and reverses by removing them.

Producer contract shapes confirmed — see `contract.md` for the full shapes. Compatibility stays **Additive**: every key is new and optional, and the omitted-key render is byte-identical. cashbot-go is a tolerant reader of `config.yaml`: it decodes with `yaml.NewDecoder` without strict field checking (`pkg/config/config.go:94-95` at `9c12fb5fc3`), already declares `processors` as integer lists and `uploadGroundx` as an `Upload` struct (`pkg/config/api.go:85-101`, `:161` at `9c12fb5fc3`), and falls back to `upload` when `uploadGroundx.baseUrl` is empty (`pkg/partner/handler.go:106-109` at `9c12fb5fc3`).

## Risks / Trade-offs

- [A processor ID points at the wrong row, so cashbot-go runs the wrong processor type on new documents] → The chart cannot detect it. The `values.yaml` comment says a new install does not need the key; the harness docs (separate change) tell operators to read IDs by type from their own `processors` table.
- [A wrong link URL makes cashbot-go stop recognizing its own links] → The schema rejects paths, credentials, queries and fragments; the bucket URL still matches stored bucket links because `bucketUrl` is unchanged.
- [Moving `upload`'s storage fields into a shared define changes whitespace] → The 850 unchanged snapshots fail the gate on any byte change.
- [An operator later enables the gateway on values that carry the new keys] → The render fails with a message naming the key. The harness docs (separate change) describe the switch: the link host moves into `file.existing.url` and `fileAccess.publicUrl`, storage moves into `fileAccess.storageEndpoint`, and both keys are removed.
- [A 0.2.7 chart rejects the new keys] → Expected: the keys exist on the 0.2.8 chart line and later. The harness PR documenting them is held until that release ships.

## Migration Plan

- **Rollout:** ships in the next `0.2.8` chart release. An upgrade with unchanged values renders the same config and restarts nothing new, because the config hash does not change. Setting a key changes `config-yaml-map`, which restarts the Go services through the existing config-hash annotation. No secret changes and no data migration.
- **Order:** this chart change, then the release, then the held harness documentation PR. Applying the values to GroundX Cloud is separate work.
- **Rollback:** remove the keys and `helm upgrade`, or `helm rollback` to the previous revision; the config returns to the defaults. Documents processed while a wrong processor ID was set are not reprocessed automatically.

## Open Questions

None. Key names, gateway interaction and the default-path proof were decided at the plan gate.
