locals {
  should_create = var.environment.vpc_id != "" && length(var.environment.subnets) > 0

  access_entries = merge({
    for entry in var.environment.cluster_role_arns : entry.name => {
      kubernetes_groups = []
      principal_arn     = entry.arn

      policy_associations = {
        cluster = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  })

  cpu_memory_desired_size = coalesce(
    var.node_replicas.cpu_memory.desired_size,
    var.nodes.node_groups.cpu_memory_nodes.desired_size
  )
  cpu_memory_max_size = coalesce(
    var.node_replicas.cpu_memory.max_size,
    var.nodes.node_groups.cpu_memory_nodes.max_size
  )
  cpu_memory_min_size = coalesce(
    var.node_replicas.cpu_memory.min_size,
    var.nodes.node_groups.cpu_memory_nodes.min_size
  )

  cpu_only_desired_size = coalesce(
    var.node_replicas.cpu_only.desired_size,
    var.nodes.node_groups.cpu_only_nodes.desired_size
  )
  cpu_only_max_size = coalesce(
    var.node_replicas.cpu_only.max_size,
    var.nodes.node_groups.cpu_only_nodes.max_size
  )
  cpu_only_min_size = coalesce(
    var.node_replicas.cpu_only.min_size,
    var.nodes.node_groups.cpu_only_nodes.min_size
  )

  gpu_layout_desired_size = coalesce(
    var.node_replicas.gpu_layout.desired_size,
    var.nodes.node_groups.layout_nodes.desired_size
  )
  gpu_layout_max_size = coalesce(
    var.node_replicas.gpu_layout.max_size,
    var.nodes.node_groups.layout_nodes.max_size
  )
  gpu_layout_min_size = coalesce(
    var.node_replicas.gpu_layout.min_size,
    var.nodes.node_groups.layout_nodes.min_size
  )

  gpu_ranker_desired_size = coalesce(
    var.node_replicas.gpu_ranker.desired_size,
    var.nodes.node_groups.ranker_nodes.desired_size
  )
  gpu_ranker_max_size = coalesce(
    var.node_replicas.gpu_ranker.max_size,
    var.nodes.node_groups.ranker_nodes.max_size
  )
  gpu_ranker_min_size = coalesce(
    var.node_replicas.gpu_ranker.min_size,
    var.nodes.node_groups.ranker_nodes.min_size
  )

  gpu_summary_desired_size = coalesce(
    var.node_replicas.gpu_summary.desired_size,
    var.nodes.node_groups.summary_nodes.desired_size
  )
  gpu_summary_max_size = coalesce(
    var.node_replicas.gpu_summary.max_size,
    var.nodes.node_groups.summary_nodes.max_size
  )
  gpu_summary_min_size = coalesce(
    var.node_replicas.gpu_summary.min_size,
    var.nodes.node_groups.summary_nodes.min_size
  )

  node_groups = merge(
    {
      cpu_memory_nodes                                      = {
        name                                                = local.cpu_memory_label

        ami_type                                            = var.nodes.node_groups.cpu_memory_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.cpu_memory_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = local.cpu_memory_desired_size
        max_size                                            = local.cpu_memory_max_size
        min_size                                            = local.cpu_memory_min_size

        ebs_optimized                                       = true
        block_device_mappings                               = {
          xvda                                              = {
            device_name                                     = "/dev/xvda"
            ebs                                             = {
              delete_on_termination                         = var.nodes.node_groups.cpu_memory_nodes.ebs.delete_on_termination
              encrypted                                     = var.nodes.node_groups.cpu_memory_nodes.ebs.encrypted
              iops                                          = var.nodes.node_groups.cpu_memory_nodes.ebs.iops
              kms_key_id                                    = var.nodes.node_groups.cpu_memory_nodes.ebs.kms_key_id
              snapshot_id                                   = var.nodes.node_groups.cpu_memory_nodes.ebs.snapshot_id
              throughput                                    = var.nodes.node_groups.cpu_memory_nodes.ebs.throughput
              volume_size                                   = max(var.deployment_type.min_pv, var.nodes.node_groups.cpu_memory_nodes.ebs.volume_size)
              volume_type                                   = var.nodes.node_groups.cpu_memory_nodes.ebs.volume_type
            }
          }
        }

        labels                                              = {
          "node"                                            = local.cpu_memory_label
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = local.cpu_memory_label
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      },
      cpu_only_nodes                                        = {
        name                                                = local.cpu_only_label

        ami_type                                            = var.nodes.node_groups.cpu_only_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.cpu_only_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = local.cpu_only_desired_size
        max_size                                            = local.cpu_only_max_size
        min_size                                            = local.cpu_only_min_size

        ebs_optimized                                       = true
        block_device_mappings                               = {
          xvda                                              = {
            device_name                                     = "/dev/xvda"
            ebs                                             = {
              delete_on_termination                         = var.nodes.node_groups.cpu_only_nodes.ebs.delete_on_termination
              encrypted                                     = var.nodes.node_groups.cpu_only_nodes.ebs.encrypted
              iops                                          = var.nodes.node_groups.cpu_only_nodes.ebs.iops
              kms_key_id                                    = var.nodes.node_groups.cpu_only_nodes.ebs.kms_key_id
              snapshot_id                                   = var.nodes.node_groups.cpu_only_nodes.ebs.snapshot_id
              throughput                                    = var.nodes.node_groups.cpu_only_nodes.ebs.throughput
              volume_size                                   = max(var.deployment_type.min_pv, var.nodes.node_groups.cpu_only_nodes.ebs.volume_size)
              volume_type                                   = var.nodes.node_groups.cpu_only_nodes.ebs.volume_type
            }
          }
        }

        labels                                              = {
          "node"                                            = local.cpu_only_label
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = local.cpu_only_label
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      },
      gpu_layout_nodes                                      = {
        name                                                = local.gpu_layout_label

        ami_type                                            = var.nodes.node_groups.layout_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.layout_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = local.gpu_layout_desired_size
        max_size                                            = local.gpu_layout_max_size
        min_size                                            = local.gpu_layout_min_size

        ebs_optimized                                       = true
        block_device_mappings                               = {
          xvda                                              = {
            device_name                                     = "/dev/xvda"
            ebs                                             = {
              delete_on_termination                         = var.nodes.node_groups.layout_nodes.ebs.delete_on_termination
              encrypted                                     = var.nodes.node_groups.layout_nodes.ebs.encrypted
              iops                                          = var.nodes.node_groups.layout_nodes.ebs.iops
              kms_key_id                                    = var.nodes.node_groups.layout_nodes.ebs.kms_key_id
              snapshot_id                                   = var.nodes.node_groups.layout_nodes.ebs.snapshot_id
              throughput                                    = var.nodes.node_groups.layout_nodes.ebs.throughput
              volume_size                                   = max(var.deployment_type.min_pv, var.nodes.node_groups.layout_nodes.ebs.volume_size)
              volume_type                                   = var.nodes.node_groups.layout_nodes.ebs.volume_type
            }
          }
        }

        labels                                              = {
          "node"                                            = local.gpu_layout_label
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = local.gpu_layout_label
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      },
      gpu_summary_nodes                                     = {
        name                                                = local.gpu_summary_label

        ami_type                                            = var.nodes.node_groups.summary_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.summary_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = local.gpu_summary_desired_size
        max_size                                            = local.gpu_summary_max_size
        min_size                                            = local.gpu_summary_min_size

        ebs_optimized                                       = true
        block_device_mappings                               = {
          xvda                                              = {
            device_name                                     = "/dev/xvda"
            ebs                                             = {
              delete_on_termination                         = var.nodes.node_groups.summary_nodes.ebs.delete_on_termination
              encrypted                                     = var.nodes.node_groups.summary_nodes.ebs.encrypted
              iops                                          = var.nodes.node_groups.summary_nodes.ebs.iops
              kms_key_id                                    = var.nodes.node_groups.summary_nodes.ebs.kms_key_id
              snapshot_id                                   = var.nodes.node_groups.summary_nodes.ebs.snapshot_id
              throughput                                    = var.nodes.node_groups.summary_nodes.ebs.throughput
              volume_size                                   = max(var.deployment_type.min_pv, var.nodes.node_groups.summary_nodes.ebs.volume_size)
              volume_type                                   = var.nodes.node_groups.summary_nodes.ebs.volume_type
            }
          }
        }

        labels                                              = {
          "node"                                            = local.gpu_summary_label
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = local.gpu_summary_label
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      } 
    },
    var.cluster.search ? {
      gpu_ranker_nodes                                      = {
        name                                                = local.gpu_ranker_label

        ami_type                                            = var.nodes.node_groups.ranker_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.ranker_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = local.gpu_ranker_desired_size
        max_size                                            = local.gpu_ranker_max_size
        min_size                                            = local.gpu_ranker_min_size

        ebs_optimized                                       = true
        block_device_mappings                               = {
          xvda                                              = {
            device_name                                     = "/dev/xvda"
            ebs                                             = {
              delete_on_termination                         = var.nodes.node_groups.ranker_nodes.ebs.delete_on_termination
              encrypted                                     = var.nodes.node_groups.ranker_nodes.ebs.encrypted
              iops                                          = var.nodes.node_groups.ranker_nodes.ebs.iops
              kms_key_id                                    = var.nodes.node_groups.ranker_nodes.ebs.kms_key_id
              snapshot_id                                   = var.nodes.node_groups.ranker_nodes.ebs.snapshot_id
              throughput                                    = var.nodes.node_groups.ranker_nodes.ebs.throughput
              volume_size                                   = max(var.deployment_type.min_pv, var.nodes.node_groups.ranker_nodes.ebs.volume_size)
              volume_type                                   = var.nodes.node_groups.ranker_nodes.ebs.volume_type
            }
          }
        }

        labels                                              = {
          "node"                                            = local.gpu_ranker_label
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = local.gpu_ranker_label
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      }
    } : {})
}

module "eyelevel_eks" {
  count = local.should_create ? 1 : 0

  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 20.0"

  enable_irsa                              = true

  cluster_name                             = local.cluster_name
  iam_role_name                            = "${local.cluster_name}-cluster-role"

  cluster_endpoint_private_access          = true
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  subnet_ids                               = var.environment.subnets
  vpc_id                                   = var.environment.vpc_id

  access_entries                           = local.access_entries

  eks_managed_node_group_defaults          = {
    iam_role_name                          = "${local.cluster_name}-node-role"
    iam_role_additional_policies           = {
      CloudWatchAgentServerPolicy          = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    }
  }

  eks_managed_node_groups                  = local.node_groups

  cluster_addons = {
    amazon-cloudwatch-observability = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }
}

resource "null_resource" "wait_for_eks" {
  count = local.should_create ? 1 : 0

  depends_on = [module.eyelevel_eks]

  provisioner "local-exec" {
    command  = "aws eks update-kubeconfig --region ${var.environment.region} --name ${local.cluster_name}"
  }
}