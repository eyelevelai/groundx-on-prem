## Why

The chart no longer ships a working OpenSearch password, but the first iteration of this change made the operator put both search passwords in `values.yaml`: an empty `search.password` or `search.privilegedPassword` fails the render. Other service credentials (`db`, the object store) can also be delivered through the cluster credentials Secret `eyelevel-secret-credentials`, which the chart already injects into the API pods as environment variables, and the maintainer decision on the ticket (2026-10-07, "do it in this one, re-use the logic other credentials use, small change") is that search credentials follow the same path. The authority for this plan is the current Linear body of GX-75 (updated 2026-10-08) and that decision, not any earlier plan or GX-26.

## What Changes

- `src/groundx/templates/_helpers/services/search.tpl`: **remove** the empty-value `fail` in `groundx.search.password` and `groundx.search.privilegedPassword`, so an empty or absent value renders without error (the operator may supply it through the cluster Secret). **Keep** the published-default hash rejection (`search.bannedPasswordHashes`) and the `mode: ingest` exemption unchanged. `config-yaml.yaml` already omits the `password:` line when the helper returns empty, so no template change is needed there.
- `src/groundx/prereqs/secret/values.yaml`: add `SEARCH_PASSWORD` and `SEARCH_INIT_PASSWORD` to the `eyelevel-secret-credentials` sample as clearly non-working placeholders (never a working value, which would recreate the original problem). These names are the environment variables the GroundX API (cashbot-go, same level) reads into `AI.AWS.Search.Password` and `Init.Search.Password` when the values keys are empty.
- Mirror the `search.tpl` change into `helm/templates/_helpers/services/search.tpl` by hand (no regen script; `verify_mirrors()` in the gate byte-compares the template trees).
- helm-unittest: replace the cases that assert an empty password fails with cases asserting (a) a published-default value fails the render naming the key, (b) an empty value renders **without error**, (c) `mode: ingest` renders no search password. Snapshots are hand-patched, never regenerated with `helm unittest -u` (AGENTS.md, GX-59). The shared test fixture keeps setting explicit passwords so no snapshot depends on a default.
- README: state that each search credential can be set through values or through the cluster Secret, that Secret-delivered passwords are not render-validated by the chart (the published-default check only sees values), and that the Secret path applies to the direct-helm route; the Terraform operator still takes both passwords as values, required when `cluster.search` is true and not needed for an ingest-only install. Update the `### Configuration` minimal-keys wording from "required" to "set via values or the Secret".
- Not changed: the removal of the published literal from tracked files, the Terraform `search` variable validation (now gated on `cluster.search`), and the OpenSearch install steps from the first iteration.

**Behavior change to flag, not breaking for existing installs:** an install that supplies neither a value nor a Secret key now renders instead of failing at render time; the failure moves to runtime (the GroundX API cannot log in to OpenSearch). That is the accepted tradeoff of the Secret path, the same as `db` and the object store, and is why the README states the render-time check does not cover Secret-delivered passwords.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `search-credential-required`: the requirement that an empty or absent `search.password` / `search.privilegedPassword` fails the render is reversed (empty is valid because the operator may supply it through the cluster Secret); the published-default rejection, the ingest exemption, the no-working-literal rule, the README requirement (now covering the values-or-Secret path) and the Terraform requirement stay. The "chart defaults alone are rejected" and "externally hosted search still needs both passwords" scenarios are replaced by empty-renders scenarios; the test-fixture requirement keeps explicit fixture passwords but no longer relies on them to make a render succeed.

## Impact

- **Files:** `src/groundx/templates/_helpers/services/search.tpl`, `helm/templates/_helpers/services/search.tpl`, `src/groundx/prereqs/secret/values.yaml`, `src/groundx/tests/*_test.yaml` search cases and affected `__snapshot__` files (hand-patched), `README.md`, and the `search-credential-required` spec.
- **Blast radius:** chart consumers only. The change relaxes a render-time check, so no existing install that sets both values stops rendering, and the rendered config for an install that sets both values is unchanged. No stateful resource, migration, or OpenSearch data is touched; no pods roll unless an operator changes their values or Secret. Environments: dev/staging/prod only redeploy when an operator next upgrades the chart.
- **Rollout and rollback:** the Secret route only works once the GroundX API image that reads `SEARCH_PASSWORD` / `SEARCH_INIT_PASSWORD` (cashbot-go, same level) is deployed; until then an operator who leaves values empty and relies on the Secret gets a runtime login failure. Operators who keep setting values are unaffected in either order. Rollback is reverting the chart; the placeholder keys in the sample Secret are inert.
- **Contract (CONSUMER):** consumes the `SEARCH_*` environment variable names that cashbot-go defines (draft: `SEARCH_PASSWORD` to `AI.AWS.Search.Password`, `SEARCH_INIT_PASSWORD` to `Init.Search.Password`) through the existing `envFrom: secretRef` injection; no new template wiring or `values.schema.json` change is needed. See workspace `openspec/changes/` for cross-service coordination and the harness follow-up.
- **Open design questions:** none. The decision between values-only, existing-Secret reference, and the cluster-Secret path was settled by the 2026-10-07 maintainer comment.
