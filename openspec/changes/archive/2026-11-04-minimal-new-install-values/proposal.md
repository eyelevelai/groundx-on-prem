## Why

The documented new-install sample uses the unsupported `groundxKey` field, so the current schema rejects it. It also includes working example passwords, unused login configuration and repeated defaults. New installations need a short list of environment-specific decisions and a complete file-access configuration without changing existing installations' chart defaults.

## What Changes

- Keep license/admin identity, cluster/storage selection, database/search credentials and protected-file endpoints in `sample.values.yaml`.
- Recommend file access in the new-install sample, with private-origin and HTTPS assertions false until verified. Use the existing storage credentials Secret instead of inline object-store credentials.
- Link identity alternatives and deployment details rather than duplicating them. Update README copy/install/upgrade instructions.
- Extend existing Helm resource tests to exercise the actual sample after operator configuration and reject unverified activation.
- Keep `AGENTS.md` as a table of contents; move detailed rules into the linked repository guide and align specification references.
- No chart templates, packaged values, schema, image tags, releases or deployments change.

## Capabilities

### New Capabilities
- `new-install-values`: minimal starter configuration and explicit verification before activation.

### Modified Capabilities
- `on-prem-identity-config`: move provider-specific identity examples out of the minimal starter.
- `eks-cluster-version-config`: retain Terraform and hosted-production rules in linked repository guidance.
- `search-credential-required`: retain test-fixture commands in linked repository guidance.
- `object-store-install-and-upgrade`: retain store wording in linked repository guidance.

## Impact

Only customers choosing the new sample receive its file-access setting. Existing values and chart defaults remain unchanged. The sample requires operator-provided endpoints, existing credentials/TLS Secrets and independently verified private origins and encrypted transport. Rendering is not storage or runtime certification.
