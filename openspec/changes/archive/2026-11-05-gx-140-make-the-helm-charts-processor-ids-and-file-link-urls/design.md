## Goals / Non-Goals

The motivation and the inventory of files are in `proposal.md`; this document records how the rework is done and why.

**Goals:**
- The values schema rejects two or more IDs for `cluster.processors.layout`, `.map` and `.summarize` before any template runs, and keeps accepting one or more IDs for the other ten lists.
- The `values.yaml` comment tells operators which three lists take one ID and which six lists the GroundX server does not read.
- Every file the link-host keys touched returns to its content on `main` at `595510d8c`, so the branch's only difference from chart 0.2.9 is the processor map.
- With `cluster.processors` unset, the rendered `config.yaml` is the same as chart 0.2.9, and the proof uses an oracle the new code cannot influence.

**Non-Goals:**
- Any change to the file-access gateway, its validation, or `fileAccess.*` rendering.
- A replacement for `file.publicUrl` or `file.groundxPublicUrl`; the operator recipe with the 0.2.9 gateway settings lives in the groundx-studio-harness docs.
- Changing default processor IDs, detecting an ID that points at the wrong database row, or making cashbot-go read the six unread lists.
- A chart version bump, a chart release, or applying values to any environment.

## Decisions

### 1. The schema enforces the count cashbot-go can start with

Invariant: the chart accepts a processor list only in a count the GroundX API and pre-process servers can start with, which is exactly one ID for `layout`, `map` and `summarize` and one or more for the other ten lists.

`"maxItems": 1` is added beside the existing `"minItems": 1` on those three properties in both `values.schema.json` files. The schema is where the chart already rejects an empty list and a misspelled key, Helm checks it before rendering any template, and the error names the property path (`at '/cluster/processors/layout': maxItems: got 2, want 1` with Helm v3.19.0, observed on a scratch copy of the chart on 2026-11-05).

Alternatives considered:
- A `fail` in the `groundx.processors` helper. Rejected: a second validation mechanism for the same map, and the message would depend on which template includes the helper first.
- Making the three keys scalars (`layout: 118`). Rejected: it changes the values shape the harness docs and evals describe, breaks the one-format rule across the 13 keys, and the rendered `config.yaml` must stay a list because cashbot-go reads `[]int`.

The other ten lists get no `maxItems`. `skipGenerate` with two IDs is the must-not-block case, because ingest mode renders one `extraPostDefaults` entry per ID. The task check also asserts directly on the schema that only these three properties carry `maxItems`, since a test covers only one of the ten unlimited lists.

### 2. The link-host removal restores files to `main` instead of unwinding edits by hand

Invariant: after the rework, every chart file the link-host keys touched is byte-identical to `main` at `595510d8c`, except the processor-map lines in `values.yaml`, `values.schema.json` and `templates/resources/config-yaml.yaml`.

The restore is per file: `templates/_helpers/app/file-access.tpl`, `templates/_helpers/services/file.tpl`, `tests/file_settings_test.yaml`, `tests/extract_test.yaml` and `docs/agents/private-file-access.md` are restored whole (in `src/groundx` and, for templates, in `helm/`). The `groundx.file.uploadStorage` helper goes with `file.tpl`, and its body returns inline in the `upload` block of `config-yaml.yaml`, because after the `uploadGroundx` section is gone it would have one caller. In `config-yaml.yaml` only the `upload` block through the end of the file is restored; the `$procs` line and the `processors` hunks stay. In `values.yaml` and `values.schema.json` only the two `file` keys and their comments are removed.

The checks compare against `git merge-base HEAD origin/main` rather than the moving `origin/main` tip, so a later `main` commit cannot turn a correct restore red before the branch syncs. Whole files use `git diff --quiet`; the partial files compare data (`jq`/`yq` with `cluster.processors` deleted) or the `upload`-to-end region, each with a non-empty guard so a failed read cannot pass as "equal".

The `MIRRORED_FILES` entries for `values.yaml` and `values.schema.json` in `.build/bin/verify-storage-contract.py` stay: they guard the processor-map mirror, which remains.

### 3. Tests reuse the existing suites

Three `failedTemplate` cases in `tests/resources_test.yaml`, one per single-ID list, each with two IDs and an `errorPattern` of `cluster/processors/<list>.*maxItems`. The existing "processor overrides render every configured list" case (one ID each) and "ingest mode builds extraPostDefaults from the configured skipGenerate IDs" case (two `skipGenerate` IDs) are the must-not-block controls. No new suite, no new snapshot. The link-host cases leave `file_settings_test.yaml` and `extract_test.yaml` with the files themselves when those return to `main`.

### 4. The default-render proof uses oracles the new code cannot change

- The committed snapshots: the full suite must pass with no snapshot file differing from the merge base.
- A verify-time differential: each fixture under `src/groundx/tests/files/` that renders at `595510d8c` is rendered there and at the branch tip, comparing the `processors` mapping (with `extraPreDefaults` and `extraPostDefaults`), the `upload` mapping, and the absence of `uploadGroundx` by named-field `yq` reads; the same `processors` comparison runs against `07d332fc6c`. A mutation run (one default ID changed in the `groundx.processors` helper on a scratch copy) shows the default snapshots go red. Output is saved under the workspace `.sdd-state/` for the ticket, never committed, and rendered bodies are never printed, because `config-yaml-map` carries credentials.

### 5. The living `file-link-urls` spec is deleted, with no delta

The change carries no `file-link-urls` delta, and a task deletes `openspec/specs/file-link-urls/`, as `proposal.md` explains under "Removed Capabilities". That spec exists only on this branch.

### 6. No ADR

Narrowing an unreleased schema property and dropping unreleased keys is reversible and stays inside one chart, so no ADR is written.

### Producer contract

The values contract the harness reads (the removed keys, the single-ID limit, the 0.2.9 gateway keys the docs use instead) is recorded in the workspace `contract.md`; this document does not repeat it.

## Risks / Trade-offs

- [A values file written against the unreleased branch that sets `file.publicUrl` or `file.groundxPublicUrl`, or gives a single-ID list two IDs, now fails validation] → No published chart carried those keys or `cluster.processors`. The failure happens at `helm upgrade` time with a named path, before anything deploys.
- [A wrong but single processor ID still passes] → The chart cannot see the database, so it cannot detect this; out of scope here, as `proposal.md` records.
- [The six unread lists stay settable, so an operator may expect them to do something] → The `values.yaml` comment names them; removing them would change the 13-key contract the requester chose to keep.
- [The restore misses a line the link-host work added outside the listed files] → The closure check greps `src`, `helm` and `docs` for `groundxPublicUrl`, `file.publicUrl` and `uploadGroundx`, and the values and schema checks compare data with `main`.

## Migration Plan

Rollout:
1. Ship with the next chart release cut from `main`. An install that does not set `cluster.processors` renders the same `config.yaml` as chart 0.2.9, so the Go services' `config-hash` annotation does not change and nothing restarts because of this change.
2. Merge the held groundx-studio-harness documentation change only after that chart release is published.
3. Setting `cluster.processors` or the gateway settings for GroundX Cloud is separate deployment work.

Blast radius: only installs that upgrade to a chart release containing this change; self-hosted customer clusters, and GroundX Cloud once it moves onto the chart. No dev, staging or production values change. No stateful resource, secret or database row is touched, and there is no SQL.

Rollback: remove `cluster.processors` from the values file or `helm rollback` to the previous revision. The schema narrowing cannot leave state behind, because a rejected values file never renders.

## Open Questions

None.
