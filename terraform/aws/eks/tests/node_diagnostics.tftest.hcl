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

override_data {
  target = data.aws_partition.current
  values = {
    partition = "aws"
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
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

run "access_settings_absent_keep_full_access" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = null
    app_irsa_sqs_queues                  = null
    cluster_endpoint_public_access_cidrs = null
  }

  assert {
    condition = jsonencode(local.app_irsa_statements) == jsonencode([
      { sid = "FullS3", actions = ["s3:*"], resources = ["*"] },
      { sid = "FullSqs", actions = ["sqs:*"], resources = ["*"] },
    ])
    error_message = "Absent S3 and SQS settings must keep the FullS3 then FullSqs statements on every resource."
  }

  assert {
    condition     = length(aws_iam_policy.s3_sqs_admin) == 1 && length(aws_iam_role_policy_attachment.attach_admin) == 1
    error_message = "Absent settings must keep exactly one S3/SQS policy and one attachment."
  }

  assert {
    condition     = jsonencode(local.cluster_endpoint_public_access_cidrs) == jsonencode(["0.0.0.0/0"])
    error_message = "An absent range setting must pass the EKS module its own default of 0.0.0.0/0."
  }
}

run "named_buckets_and_queues_are_scoped" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = ["groundx-files", "extract-bucket"]
    app_irsa_sqs_queues                  = ["file-process"]
    cluster_endpoint_public_access_cidrs = null
  }

  assert {
    condition = jsonencode(local.app_irsa_statements) == jsonencode([
      {
        sid       = "S3Buckets"
        actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
        resources = ["arn:aws:s3:::groundx-files", "arn:aws:s3:::extract-bucket"]
      },
      {
        sid       = "S3Objects"
        actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging", "s3:AbortMultipartUpload"]
        resources = ["arn:aws:s3:::groundx-files/*", "arn:aws:s3:::extract-bucket/*"]
      },
      {
        sid       = "SqsQueues"
        actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
        resources = ["arn:aws:sqs:us-west-2:123456789012:file-process"]
      },
    ])
    error_message = "Named buckets and queues must get only their own bucket, object and queue ARNs, never *."
  }

  assert {
    condition     = length(aws_iam_policy.s3_sqs_admin) == 1 && length(aws_iam_role_policy_attachment.attach_admin) == 1
    error_message = "Named settings must keep exactly one S3/SQS policy and one attachment."
  }
}

run "empty_s3_with_named_queues_has_no_s3_statement" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = []
    app_irsa_sqs_queues                  = ["file-process"]
    cluster_endpoint_public_access_cidrs = null
  }

  assert {
    condition = jsonencode(local.app_irsa_statements) == jsonencode([
      {
        sid       = "SqsQueues"
        actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
        resources = ["arn:aws:sqs:us-west-2:123456789012:file-process"]
      },
    ])
    error_message = "An empty S3 list must remove every S3 statement and leave only the named queue."
  }
}

run "empty_sqs_with_named_buckets_has_no_sqs_statement" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = ["groundx-files"]
    app_irsa_sqs_queues                  = []
    cluster_endpoint_public_access_cidrs = null
  }

  assert {
    condition = jsonencode(local.app_irsa_statements) == jsonencode([
      {
        sid       = "S3Buckets"
        actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
        resources = ["arn:aws:s3:::groundx-files"]
      },
      {
        sid       = "S3Objects"
        actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging", "s3:AbortMultipartUpload"]
        resources = ["arn:aws:s3:::groundx-files/*"]
      },
    ])
    error_message = "An empty SQS list must remove every SQS statement and leave only the named bucket."
  }
}

run "empty_s3_keeps_absent_sqs_at_full_access" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = []
    app_irsa_sqs_queues                  = null
    cluster_endpoint_public_access_cidrs = null
  }

  assert {
    condition = jsonencode(local.app_irsa_statements) == jsonencode([
      { sid = "FullSqs", actions = ["sqs:*"], resources = ["*"] },
    ])
    error_message = "S3 and SQS must be decided independently: an empty S3 list must not change absent SQS access."
  }
}

run "both_lists_empty_attach_no_policy_and_keep_the_role" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = []
    app_irsa_sqs_queues                  = []
    cluster_endpoint_public_access_cidrs = null
  }

  assert {
    condition     = length(aws_iam_policy.s3_sqs_admin) == 0 && length(aws_iam_role_policy_attachment.attach_admin) == 0 && length(data.aws_iam_policy_document.s3_sqs_admin) == 0
    error_message = "Both lists empty must plan no S3/SQS policy document, policy or attachment."
  }

  assert {
    condition     = aws_iam_role.app_irsa.name == "eyelevel-s3-sqs-worker-irsa"
    error_message = "Both lists empty must keep the application role."
  }
}

run "named_ranges_reach_the_endpoint_input" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = null
    app_irsa_sqs_queues                  = null
    cluster_endpoint_public_access_cidrs = ["203.0.113.5/32", "198.51.100.0/24"]
  }

  assert {
    condition     = jsonencode(local.cluster_endpoint_public_access_cidrs) == jsonencode(["203.0.113.5/32", "198.51.100.0/24"])
    error_message = "Named ranges must be passed to the EKS module unchanged."
  }
}

run "empty_range_list_is_rejected" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = null
    app_irsa_sqs_queues                  = null
    cluster_endpoint_public_access_cidrs = []
  }

  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}

run "bare_address_without_a_range_is_rejected" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = null
    app_irsa_sqs_queues                  = null
    cluster_endpoint_public_access_cidrs = ["203.0.113.5"]
  }

  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}

run "wildcard_bucket_name_is_rejected" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = ["groundx-files", "*"]
    app_irsa_sqs_queues                  = null
    cluster_endpoint_public_access_cidrs = null
  }

  expect_failures = [var.app_irsa_s3_buckets]
}

run "wildcard_queue_name_is_rejected" {
  command = plan

  variables {
    app_irsa_s3_buckets                  = null
    app_irsa_sqs_queues                  = ["file-process", "*"]
    cluster_endpoint_public_access_cidrs = null
  }

  expect_failures = [var.app_irsa_sqs_queues]
}
