## Context

The production EKS KMS key contains an Inspector SBOM export statement added
outside the legacy Terraform. Even a targeted node-monitoring add-on plan walks
the EKS module dependency graph and proposes removing that statement.

## Goals / Non-Goals

**Goals:**

- Represent existing external KMS statements without changing them.
- Keep omitted behavior unchanged for every environment.
- Produce a targeted production plan containing only the diagnostic add-on.

**Non-Goals:**

- Apply Terraform or change the live KMS key.
- Resolve the unrelated CloudWatch add-on version drift.
- Move production EKS ownership before the active infrastructure adoption is
  ready.

## Decisions

Add a default-empty `eks_kms_source_policy_documents` list and pass it directly
to the pinned EKS module's `kms_key_source_policy_documents` input. This follows
the module's native policy-merge contract and avoids hard-coding Inspector into
all installations.

Keep the exact Inspector JSON only in the ignored production `env.tfvars`.
Other environments receive no new statement or required setting.

Do not use lifecycle ignores, temporary override files, or manual AWS changes.
Those approaches would hide drift, make the reviewed plan non-reproducible, or
leave Terraform unable to preserve the live policy on the next run.

## Risks / Trade-offs

- Incorrect policy JSON could rewrite the KMS policy. Mitigation: copy the live
  statement exactly and require a plan with no KMS action.
- The input extends deprecated Terraform. Mitigation: keep it as a direct,
  default-empty pass-through and move ownership to `groundx-production-infra`
  through its existing adoption plan.
- The full plan still proposes a CloudWatch add-on upgrade. Mitigation: review
  only the exact targeted diagnostic plan and do not apply the full plan.

## Migration Plan

1. Add a failing Terraform test for the default and configured pass-through.
2. Add the input and pass it to the existing EKS module.
3. Put the exact live Inspector statement in production `env.tfvars`.
4. Require the targeted production plan to show one add and no other action.
5. Submit the code against `0.2.7`. Do not apply.

Rollback removes the code input only after production EKS ownership moves or
the external statement is otherwise represented. Removing it from the active
legacy configuration earlier would again plan KMS policy removal.

## Open Questions

None.
