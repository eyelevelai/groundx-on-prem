mock_provider "aws" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "null" {}
mock_provider "random" {}

variables {
  environment = {
    cluster_role_arns = []
    region            = "us-west-2"
    security_groups   = []
    ssh_key_name      = "test"
    stage             = "test"
    subnets           = ["subnet-test"]
    vpc_id            = "vpc-test"
  }
}

override_data {
  target = data.aws_iam_policy_document.app_irsa_trust
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.s3_sqs_admin
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_module {
  target = module.eyelevel_eks
  outputs = {
    cluster_endpoint  = "https://example.invalid"
    oidc_provider     = "oidc.eks.us-west-2.amazonaws.com/id/test"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/test"
  }
}

override_module {
  target = module.irsa_autoscaler
  outputs = {
    iam_role_arn = "arn:aws:iam::123456789012:role/test-autoscaler"
  }
}

override_module {
  target = module.irsa_efs_csi
  outputs = {
    iam_role_arn = "arn:aws:iam::123456789012:role/test-efs-csi"
  }
}

run "diagnostics_are_disabled_by_default" {
  command = plan

  assert {
    condition     = var.node_diagnostics.enabled == false
    error_message = "Node diagnostics must default to disabled."
  }

  assert {
    condition     = !contains(keys(local.cluster_addons), "eks-node-monitoring-agent")
    error_message = "The node monitoring add-on must be absent by default."
  }
}

run "diagnostics_are_disabled_explicitly" {
  command = plan

  variables {
    node_diagnostics = {
      enabled = false
    }
  }

  assert {
    condition     = !contains(keys(local.cluster_addons), "eks-node-monitoring-agent")
    error_message = "The node monitoring add-on must be absent when disabled."
  }
}

run "diagnostics_cover_only_cpu_pools" {
  command = plan

  variables {
    node_diagnostics = {
      enabled = true
    }
  }

  assert {
    condition     = local.cluster_addons["eks-node-monitoring-agent"].addon_version == "v1.7.0-eksbuild.1"
    error_message = "The node monitoring add-on version must be pinned."
  }

  assert {
    condition = jsondecode(local.cluster_addons["eks-node-monitoring-agent"].configuration_values).nodeAgent.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0] == {
      key      = "eyelevel_node"
      operator = "In"
      values   = [local.cpu_only_label, local.cpu_memory_label]
    }
    error_message = "The node agent must target both configured CPU pools."
  }

  assert {
    condition     = jsondecode(local.cluster_addons["eks-node-monitoring-agent"].configuration_values).nodeAgent.monitors.nvidia.enabled == false
    error_message = "The node monitoring add-on NVIDIA monitor must be disabled."
  }

  assert {
    condition     = jsondecode(local.cluster_addons["eks-node-monitoring-agent"].configuration_values).dcgmAgent.nodeSelector["diagnostics.groundx.ai/dcgm"] == "disabled"
    error_message = "The add-on DCGM component must have no eligible nodes."
  }
}
