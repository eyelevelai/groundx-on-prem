## 1. Define The Safety Contract

- [x] 1.1 Verify the targeted production plan includes the existing KMS policy
  removal through the EKS module dependency graph.
- [x] 1.2 Record the default-empty pass-through design and zero-change KMS gate.

## 2. Implement With TDD

- [x] 2.1 Add a failing Terraform test proving omitted input is empty and a
  configured source policy document reaches the EKS module unchanged.
- [x] 2.2 Add the minimal typed input and EKS module pass-through.
- [x] 2.3 Add the exact existing Inspector statement to ignored production
  `env.tfvars` without changing Helm values.

## 3. Validate And Submit

- [x] 3.1 Run the focused Terraform test, `terraform validate`, formatting,
  strict OpenSpec validation, and `git diff --check`.
- [x] 3.2 Review a targeted production plan and prove it contains exactly one
  add-on creation, with no KMS, CloudWatch, Helm, update, replacement, or
  deletion action.
- [ ] 3.3 Submit the change against `0.2.7`. Do not apply Terraform.

Production plan evidence, 2026-08-22: the targeted plan against account
`903713046261`, region `us-west-2`, and cluster `eyelevel_890ng3` contained one
creation, `eks-node-monitoring-agent` `v1.7.0-eksbuild.1`, and 61 no-op
resources. It contained no update, replacement, or deletion. The plan was not
applied.
