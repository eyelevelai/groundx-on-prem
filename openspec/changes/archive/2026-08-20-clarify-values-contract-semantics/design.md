## Context

`cluster.hasMig` and `cluster.tls.existingSecret` entered the strict values schema during an older chart reorganization. The Helm chart never connected them to current templates. `groundx.hasMig` is an unused helper, and `NOTES.txt` instead reads a different top-level TLS path that the schema rejects.

## Goals / Non-Goals

**Goals:**

- Preserve 0.2.7 values compatibility while making the no-op behavior explicit.
- Remove dead or misleading template code.
- Protect the contract with source-backed render checks on both chart surfaces.

**Non-Goals:**

- Invent a MIG profile from one boolean.
- Add cluster-wide workload TLS without defined consumers, ports, mounts, or trust stores.
- Change application images, workload manifests, stateful resources, or live Secrets.

## Decisions

Keep both fields schema-valid and add `deprecated: true` plus a precise description. Removing them would turn previously accepted values into upgrade failures. Implementing them would create undefined deployment behavior.

Remove `groundx.hasMig` because no current template calls it. Remove the Internal TLS section from `NOTES.txt` because neither the schema-valid field nor its incorrect top-level alias is consumed.

Extend `.build/bin/validate-helm.sh` rather than add a second test entrypoint. The production gate will parse both schemas, compare default renders with each deprecated field set, reject a reintroduced helper or TLS note, and continue running the existing lint, unit, and render checks.

No ADR is needed. This records existing behavior and compatibility rather than introducing an architectural contract.

## Risks / Trade-offs

- The fields remain accepted, so a deployer using only Helm output will not receive a runtime warning. Mitigation: schema tooling exposes deprecation metadata, operator guidance stops recommending the fields, and the next breaking chart version can remove them.
- Render equivalence intentionally freezes these fields as inert in 0.2.7. Mitigation: a future implementation must deliberately update the spec and contract test.
- `helm/` is a manual mirror. Mitigation: the production gate validates both chart surfaces.

## Migration Plan

Ship the source and mirror changes together. No environment redeploy, data migration, Secret rotation, or stateful rollout is required. Roll back by reverting the chart metadata, helper, note, and gate changes. Roll forward by removing the deprecated fields in a future breaking chart release or replacing them with fully specified values.

## Open Questions

None.
