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

  node_groups = merge(
    {
      cpu_memory_nodes                                      = {
        name                                                = var.cluster.nodes.cpu_memory

        ami_type                                            = var.nodes.node_groups.cpu_memory_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.cpu_memory_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = var.nodes.node_groups.cpu_memory_nodes.desired_size
        max_size                                            = var.nodes.node_groups.cpu_memory_nodes.max_size
        min_size                                            = var.nodes.node_groups.cpu_memory_nodes.min_size

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
          "node"                                            = var.cluster.nodes.cpu_memory
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = var.cluster.nodes.cpu_memory
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      },
      cpu_only_nodes                                        = {
        name                                                = var.cluster.nodes.cpu_only

        ami_type                                            = var.nodes.node_groups.cpu_only_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.cpu_only_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = var.nodes.node_groups.cpu_only_nodes.desired_size
        max_size                                            = var.nodes.node_groups.cpu_only_nodes.max_size
        min_size                                            = var.nodes.node_groups.cpu_only_nodes.min_size

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
          "node"                                            = var.cluster.nodes.cpu_only
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = var.cluster.nodes.cpu_only
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      },
      gpu_layout_nodes                                      = {
        name                                                = var.cluster.nodes.gpu_layout

        ami_type                                            = var.nodes.node_groups.layout_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.layout_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = var.nodes.node_groups.layout_nodes.desired_size
        max_size                                            = var.nodes.node_groups.layout_nodes.max_size
        min_size                                            = var.nodes.node_groups.layout_nodes.min_size

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
          "node"                                            = var.cluster.nodes.gpu_layout
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = var.cluster.nodes.gpu_layout
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      },
      gpu_summary_nodes                                     = {
        name                                                = var.cluster.nodes.gpu_summary

        ami_type                                            = var.nodes.node_groups.summary_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.summary_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = var.nodes.node_groups.summary_nodes.desired_size
        max_size                                            = var.nodes.node_groups.summary_nodes.max_size
        min_size                                            = var.nodes.node_groups.summary_nodes.min_size

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
          "node"                                            = var.cluster.nodes.gpu_summary
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = var.cluster.nodes.gpu_summary
          Terraform                                         = "true"
          "k8s.io/cluster-autoscaler/enabled"               = "true"
          "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
        }
      } 
    },
    var.cluster.search ? {
      gpu_ranker_nodes                                      = {
        name                                                = var.cluster.nodes.gpu_ranker

        ami_type                                            = var.nodes.node_groups.ranker_nodes.ami_type
        instance_types                                      = var.nodes.node_groups.ranker_nodes.instance_types
        key_name                                            = var.environment.ssh_key_name
        vpc_security_group_ids                              = var.environment.security_groups

        desired_size                                        = var.nodes.node_groups.ranker_nodes.desired_size
        max_size                                            = var.nodes.node_groups.ranker_nodes.max_size
        min_size                                            = var.nodes.node_groups.ranker_nodes.min_size

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
          "node"                                            = var.cluster.nodes.gpu_ranker
        }

        tags                                                = {
          Environment                                       = var.environment.stage
          Name                                              = var.cluster.nodes.gpu_ranker
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
  }

  eks_managed_node_groups                  = local.node_groups
}

resource "null_resource" "wait_for_eks" {
  count = local.should_create ? 1 : 0

  depends_on = [module.eyelevel_eks]

  provisioner "local-exec" {
    command  = "aws eks update-kubeconfig --region ${var.environment.region} --name ${local.cluster_name}"
  }
}