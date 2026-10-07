## Why

Enabling EKS node diagnostics cannot produce an isolated production plan because
the legacy Terraform does not model an existing Inspector statement on the
cluster KMS key. The targeted plan would remove that permission.

## What Changes

- Add one optional list of KMS source policy documents, defaulting to empty.
- Pass configured documents unchanged to the pinned EKS module.
- Preserve the existing production Inspector SBOM export statement through the
  ignored production `env.tfvars`.
- Require the targeted production plan to create only the node monitoring
  add-on before any separately approved apply.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `eks-node-diagnostics`: A diagnostic rollout must preserve explicitly
  configured cluster KMS policy statements.

## Impact

- Blast radius: none by default. No cluster redeploys and no AWS resource changes
  occur until an operator applies a reviewed plan.
- Affected environments: only AWS EKS environments that explicitly provide KMS
  source policy documents. The production value describes permission already
  present in AWS.
- Stateful impact: none. The change does not modify data, Helm, workloads, node
  groups, or the existing live KMS policy.
- Rollforward: merge the default-empty input, set the production-only value, and
  require a one-create, zero-update, zero-delete targeted plan.
- Rollback: omit the new input. Do not apply that rollback where external KMS
  statements must remain.
- Open design questions: none.
