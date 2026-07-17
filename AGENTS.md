# AGENTS.md

Table of contents. Read the route that matches the change; keep durable rules
in the linked docs, not in this entrypoint.

| Topic | Read when |
|---|---|
| [Repo guide](docs/agents/repo-guide.md) | You need the Helm/on-prem model, privileged-operation boundaries, editable paths, OpenSpec rules, or repo gotchas. |
| [Contributor workflow](CONTRIBUTING.md) | You are preparing a PR, choosing validation, writing PR notes, or deciding what belongs in committed comments. |
| [`src/groundx/`](src/groundx/) | You are changing the source Helm chart. This is the chart source of truth. |
| [`helm/`](helm/) | You are checking the published chart mirror. Do not hand-edit it without mirroring the matching `src/groundx/` change. |
| [`src/groundx/values.schema.json`](src/groundx/values.schema.json) | You are changing the deployment contract. Treat as broad blast radius. |
| [`src/groundx/tests/`](src/groundx/tests/) | You are updating or verifying Helm unit-test snapshots. |
| [`bin/`](bin/) | You are inspecting operator tooling. Do not run destructive or deploy/publish commands without explicit human authorization. |
