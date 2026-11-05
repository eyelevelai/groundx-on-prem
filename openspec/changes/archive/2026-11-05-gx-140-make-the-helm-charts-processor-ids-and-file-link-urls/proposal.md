## Why

The unreleased `cluster.processors` setting lets a values file give `layout`, `map` and `summarize` several processor IDs, but the GroundX API and pre-process servers stop at startup unless each of those three lists holds exactly one ID. cashbot-go's copier returns an error for any other count (`pkg/copy/copy.go:61-72` at cashbot-go `1bc6431ccc`), and both servers treat that error as fatal (`server/GroundX/main.go:251-258`, `server/PreProcessTrainFile/main.go:209-212`). The chart should reject such a values file before it deploys a server that cannot start.

The same unreleased change also added `file.publicUrl` and `file.groundxPublicUrl`, which set file link hosts with the file-access gateway turned off. In review on 2026-11-04 the chart owner asked why both link hosts could not point to the file-access gateway and let it decide who may download each file. The requester approved that direction on 2026-11-05. Chart 0.2.9 already has the settings that direction needs: `fileAccess.publicUrl` for the host of new links and `fileAccess.trustedOrigins` for the hosts stored links use. The two link-host keys are therefore removed rather than shipped.

## What Changes

- `cluster.processors.layout`, `cluster.processors.map` and `cluster.processors.summarize` accept exactly one ID. A values file that gives any of them two or more IDs fails schema validation, so no manifest renders.
- The other ten lists (`convert`, `extract`, `saveFile`, `skipConvert`, `skipGenerate`, `skipLayout`, `skipMap`, `skipSummarize`, `summarizeChunks`, `summarizeSections`) keep accepting one or more IDs. All 13 lists stay overridable.
- The `cluster.processors` comment in `values.yaml` names the three single-ID lists and the six lists cashbot-go does not read at `1bc6431ccc` (`saveFile`, `skipConvert`, `skipLayout`, `skipMap`, `summarizeChunks`, `summarizeSections`). Those six exist only as config struct fields there (`pkg/config/api.go:91-107`).
- `file.publicUrl` and `file.groundxPublicUrl` are removed from `values.yaml` and `values.schema.json`, along with the template code that served them: the `upload.baseUrl` override, the `uploadGroundx` section, the link hosts added to the layout and extraction storage alias list, and the two gateway-on render failures. Nothing replaces them in the chart. These files return to their content on `main` at `595510d8c`: `templates/_helpers/app/file-access.tpl`, `templates/_helpers/services/file.tpl`, the `upload` block of `templates/resources/config-yaml.yaml`, `tests/file_settings_test.yaml`, `tests/extract_test.yaml` and `docs/agents/private-file-access.md`.
- With `cluster.processors` unset, the rendered `config.yaml` stays identical to `main`: the `processors` block, the `extraPreDefaults` and ingest-mode `extraPostDefaults` entries, and the `upload` section. No `uploadGroundx` section renders. No committed snapshot changes.
- `src/groundx` and the hand-maintained `helm/` mirror change together, and the two `values.schema.json` files stay byte-identical.
- No chart version bump and no image tag change. Publishing a chart release is out of scope.

Not breaking for any published chart: no released chart ever carried `cluster.processors`, `file.publicUrl` or `file.groundxPublicUrl` (chart 0.2.9 on `main` has none of them). Only a values file written against the unreleased branch and setting one of the two link keys, or giving a single-ID list more than one ID, now fails validation.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `processor-id-overrides`: `layout`, `map` and `summarize` take exactly one ID while the other ten lists keep taking one or more; the `values.yaml` comment names the single-ID lists and the six unread lists; the unchanged-defaults requirement compares against `main` at `595510d8c` instead of the retired `0.2.8` branch, keeping the 0.2.7 (`07d332fc6c`) comparison.

### Removed Capabilities
- `file-link-urls`: the whole capability is retired by deleting `openspec/specs/file-link-urls/`. It exists only on this branch and never reached `main`. It has no delta spec because OpenSpec 1.4.1 refuses to archive a change whose REMOVED delta would empty a capability. The five retired requirements:
  1. "A separate file link host without the gateway"
  2. "An optional GroundX alias section"
  3. "Layout and extraction read files linked on either link host from storage"
  4. "The link host keys are rejected when the file-access gateway is enabled"
  5. "Omitting both link keys leaves the upload configuration unchanged"

  **Reason:** link hosts go through the file-access gateway instead of gateway-off chart values, following the chart owner's 2026-11-04 review and the requester's 2026-11-05 decision.
  **Migration:** use the chart 0.2.9 settings. With the gateway on, `fileAccess.publicUrl` is the host for new links and `fileAccess.trustedOrigins` lists the hosts that stored links use. With the gateway off, `fileAccess.trustedOrigins` alone lists the extra hosts. cashbot-go counts `fileAccess.publicUrl` and each trusted origin as its own file roots (`pkg/config/upload.go:44-61` at `1bc6431ccc`), and with no `uploadGroundx` section it uses `upload` for GroundX links (`pkg/partner/handler.go:116-119`). The groundx-studio-harness docs for this feature describe that setup.

## Impact

- **Code:** `src/groundx/values.schema.json` and `src/groundx/values.yaml`, the files listed above that return to `main`, the matching `helm/` files, and one schema reject case per single-ID list in the existing `tests/resources_test.yaml`. The `groundx.processors` helper in `templates/_helpers/main.tpl`, the `processors` rendering in `config-yaml.yaml`, and the two `MIRRORED_FILES` entries in `.build/bin/verify-storage-contract.py` stay. No new test file, no new snapshot suite. `.build/bin/validate-helm.sh` gates the change.
- **Consumers:** cashbot-go reads the rendered `config.yaml` and needs no change: it already requires one ID for the three lists and falls back to `upload` when `uploadGroundx` is absent. groundx-studio-harness documents the single-ID rule and the gateway setup in its own change, held until a chart release carries `cluster.processors`.
- **Blast radius:** only installs that upgrade to a chart release containing this change. Such an install renders the same `config.yaml` as chart 0.2.9 unless the operator sets `cluster.processors`. The narrowed schema can only reject values that would have stopped the GroundX API and pre-process servers at startup. A processor ID that points at the wrong database row still makes cashbot-go run the wrong processor type; the chart cannot see the database, so this change does not detect that.
- **Environments:** self-hosted customer clusters, and GroundX Cloud once it moves onto the chart. No dev, staging or production values change, and applying values to the GroundX Cloud deployment is out of scope.
- **Data and stateful resources:** none. The `processors` table, storage buckets and stored file links are not touched.
- **Rollback / roll-forward:** remove `cluster.processors` from the values file, or `helm rollback` to the previous revision, and the config returns to the default IDs. After a wrong ID, correct it and run `helm upgrade`. Documents processed while a wrong ID was set are not reprocessed automatically.
- **Open design questions:** none. The requester's 2026-11-05 decisions and the plan gate settled the single-ID rule, the removal of both link keys, and how the unchanged defaults are proven.
