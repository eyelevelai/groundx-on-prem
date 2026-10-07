# Workspace Ownership Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the runner's default-on ownership-check setting through the Helm chart.

**Architecture:** One strict Helm value renders into the existing shared runner `config.py`. The ConfigMap hash rolls the API and all workers. Source chart files are mirrored into the published chart.

**Tech Stack:** Helm 3, Go templates, JSON Schema, helm-unittest, OpenSpec.

---

### Task 1: Add failing chart tests

**Files:**

- Modify: `src/groundx/tests/workspace_test.yaml`

- [ ] Add a default test that renders `workspace-config-py.yaml` and matches:

```yaml
- matchRegex:
    path: data["config.py"]
    pattern: "workspace_ownership_checks_enabled=True"
```

- [ ] Add an explicit false test with:

```yaml
set:
  workspace.ownershipChecksEnabled: false
```

and match `workspace_ownership_checks_enabled=False`.

- [ ] Run `helm unittest src/groundx -f workspace_test.yaml`. Expected: both
  tests fail because the setting is not rendered.

### Task 2: Add the source chart contract

**Files:**

- Modify: `src/groundx/values.yaml`
- Modify: `src/groundx/values.schema.json`
- Modify: `src/groundx/templates/_helpers/app/workspace.tpl`
- Modify: `src/groundx/templates/resources/workspace-config-py.yaml`
- Modify: `README.md`

- [ ] Add the safe default:

```yaml
workspace:
  ownershipChecksEnabled: true
```

- [ ] Add the strict schema property:

```json
"ownershipChecksEnabled": { "type": "boolean" }
```

- [ ] Add the helper:

```gotemplate
{{- define "groundx.workspace.ownershipChecksEnabled" -}}
{{- $in := include "groundx.workspace.values" . | fromYaml -}}
{{ dig "ownershipChecksEnabled" true $in }}
{{- end }}
```

- [ ] Render the Python boolean:

```gotemplate
workspace_ownership_checks_enabled={{ if eq (printf "%v" (include "groundx.workspace.ownershipChecksEnabled" .)) "true" }}True{{ else }}False{{ end }},
```

- [ ] Document that false bypasses only runner ownership comparisons, rolls all
  workspace pods, and requires the compatible runner image first.

- [ ] Run the focused Helm tests. Expected: both pass.

### Task 3: Mirror and regenerate

**Files:**

- Modify matching files under `helm/`
- Regenerate: `src/groundx/tests/__snapshot__/workspace_test.yaml.snap`

- [ ] Copy the source chart changes exactly into the published mirror.
- [ ] Run `helm unittest -u src/groundx` to regenerate snapshots.
- [ ] Confirm only expected snapshots changed.
- [ ] Compare each changed source file with its mirror counterpart.

### Task 4: Verify and commit

- [ ] Run:

```bash
helm lint src/groundx
helm template groundx src/groundx -f src/groundx/values/minikube/values.yaml >/tmp/groundx-workspace-ownership.yaml
helm unittest src/groundx
OPENSPEC_TELEMETRY=0 npx --yes @fission-ai/openspec@1.3.1 validate --all --strict --json
git diff --check
```

- [ ] Confirm the default render is `True`, explicit false is `False`, invalid
  schema input fails, and no resource shape changes beyond ConfigMap content and
  rollout hashes.
- [ ] Commit and open a PR against production branch `0.2.7`.
