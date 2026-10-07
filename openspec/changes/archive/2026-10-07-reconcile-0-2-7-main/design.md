## Context

Main contains the generated Ingress backend fix and contributor guidance. The release branch contains managed-data MySQL CA configuration, Secret-backed configuration, Redis authentication, and the 0.2.7 chart package. The merge conflicts largely overlap additions that the release branch already carries.

## Goals / Non-Goals

Preserve both branches' functional changes and produce a matching source, package, and unpacked chart. Release automation, cloud publishing, and cluster installation remain outside this reconciliation.

## Decisions

Resolve individual conflict regions, retaining release-branch TLS and Secret test assertions while accepting nonconflicting main changes. Restore CONTRIBUTING.md. Keep source tests under src/groundx and let Helm's .helmignore determine packaged contents.

Build the main chart with Helm 3.19.0 and regenerate helm from the resulting archive. The package remains version 0.2.7. Use isolated tool binaries and the pinned helm-unittest 1.1.2 plugin for validation.

## Risks / Trade-offs

Incorrect workspace conflict resolution could drop CA mounting or Secret payload assertions. Existing workspace tests cover the API and all workers. The ingress fix changes package contents, so the rebuilt archive must be published separately before it becomes the registry's 0.2.7 artifact.

## Migration Plan

Validate both chart surfaces, publish the reconciled Git branch, and run PR integration jobs before merging into main. No environment or persistent data changes occur. Revert the reconciliation commit and package together for rollback. Publishing and deployment require separate operator authorization.

## Protected Extraction Surfaces

Arcadia legacy, Arcadia v1, generic v1, and ADP v1 workflow schemas, prompts, and task chains are unchanged. The existing source chart suite covers extraction render compatibility; this reconciliation changes Ingress backend naming and retains existing workspace configuration. Customer extraction replay is not required for these unchanged workflow surfaces.

## Open Questions

None.
