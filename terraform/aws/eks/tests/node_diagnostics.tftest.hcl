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

run "dns_collection_is_disabled_by_default" {
  command = plan

  assert {
    condition     = var.dns_observability.enabled == false && length(local.cloudwatch_configuration.agents) == 1 && local.cluster_addons["amazon-cloudwatch-observability"].addon_version == null
    error_message = "DNS collection must remain off without removing the main CloudWatch agent."
  }
}

run "dns_collection_keeps_container_insights_and_scrapes_coredns_once" {
  command = plan

  variables {
    dns_observability = { enabled = true }
  }

  assert {
    condition     = local.cluster_addons["amazon-cloudwatch-observability"].addon_version == "v5.4.0-eksbuild.1"
    error_message = "The tested CloudWatch add-on version must be pinned when DNS collection is enabled."
  }

  assert {
    condition     = local.cloudwatch_configuration.agents[0].config.logs.metrics_collected.kubernetes.enhanced_container_insights
    error_message = "Detailed Container Insights must remain enabled with DNS collection."
  }

  assert {
    condition     = length(local.cloudwatch_configuration.agents) == 2 && !local.cloudwatch_configuration.manager.applicationSignals.autoMonitor.monitorAllServices && !local.cloudwatch_configuration.manager.applicationSignals.autoMonitor.restartPods
    error_message = "DNS collection must retain the cost controls and add exactly one collector."
  }

  assert {
    condition     = local.cloudwatch_configuration.agents[1].mode == "deployment"
    error_message = "CoreDNS metrics must be scraped by only one collector deployment."
  }

  assert {
    condition     = local.cloudwatch_configuration.agents[1].prometheus.config.scrape_configs[0].kubernetes_sd_configs[0].namespaces.names[0] == "kube-system"
    error_message = "The collector must discover CoreDNS in kube-system."
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
    condition     = local.cluster_addons["eks-node-monitoring-agent"].preserve == false
    error_message = "Disabling diagnostics must delete the managed add-on."
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

run "kms_source_policy_documents_default_empty" {
  command = plan

  assert {
    condition     = length(local.eks_kms_source_policy_documents) == 0
    error_message = "Additional EKS KMS source policy documents must default to empty."
  }
}

run "kms_source_policy_documents_pass_through" {
  command = plan

  variables {
    eks_kms_source_policy_documents = [
      "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"KeepExistingPolicy\"}]}"
    ]
  }

  assert {
    condition     = local.eks_kms_source_policy_documents == var.eks_kms_source_policy_documents
    error_message = "Configured EKS KMS source policy documents must pass through unchanged."
  }
}

run "unset_version_resolves_to_null" {
  command = plan

  variables {
    environment_internal = {}
  }

  assert {
    condition     = var.environment_internal.eks_version == null
    error_message = "An unset version key must resolve to null, not any implicit default."
  }
}

run "cpu_only_disks_use_gp3_without_changing_other_pools" {
  command = plan

  assert {
    condition     = local.node_groups.cpu_only_nodes.block_device_mappings.xvda.ebs.volume_type == "gp3" && local.node_groups.cpu_only_nodes.block_device_mappings.xvda.ebs.iops == 3000 && local.node_groups.cpu_only_nodes.block_device_mappings.xvda.ebs.throughput == 128
    error_message = "The CPU-only launch template must use gp3 with 3000 IOPS and 128 MiB/s."
  }

  assert {
    condition     = local.node_groups.cpu_only_nodes.block_device_mappings.xvda.ebs.encrypted && local.node_groups.cpu_only_nodes.block_device_mappings.xvda.ebs.delete_on_termination && tonumber(var.nodes.node_groups.cpu_only_nodes.ebs.volume_size) == 30
    error_message = "CPU root disk size, encryption, and deletion behavior must be preserved."
  }

  assert {
    condition     = local.node_groups.cpu_only_nodes.update_config.max_unavailable == 1 && !contains(keys(local.node_groups.cpu_only_nodes.update_config), "max_unavailable_percentage")
    error_message = "Only one old CPU node may be unavailable during an update."
  }

  assert {
    condition     = alltrue([for name, group in local.node_groups : group.block_device_mappings.xvda.ebs.volume_type == "gp2" if name != "cpu_only_nodes"])
    error_message = "Other node groups must retain their existing disk types."
  }
}

run "cloudwatch_cost_settings_apply_without_dns_collection" {
  command = plan

  assert {
    condition     = !local.cloudwatch_configuration.manager.applicationSignals.autoMonitor.monitorAllServices && !local.cloudwatch_configuration.manager.applicationSignals.autoMonitor.restartPods
    error_message = "Application Signals auto-monitoring and automatic application restarts must be disabled."
  }

  assert {
    condition     = local.cloudwatch_configuration.agents[0].config.logs.metrics_collected.kubernetes.enhanced_container_insights
    error_message = "Detailed Container Insights must remain enabled."
  }

  assert {
    condition     = keys(local.cloudwatch_configuration.agents[0].config.logs.metrics_collected) == ["kubernetes"] && !contains(keys(local.cloudwatch_configuration.agents[0].config), "traces") && !contains(keys(local.cloudwatch_configuration.agents[0].config), "metrics")
    error_message = "CloudWatch agent config must not contain Application Signals collection."
  }
}
