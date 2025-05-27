# ENVIRONMENT

variable "environment" {
  description         = "Environment information for the Kubernetes cluster"
  type                = object({
    cluster_role_arns = list(object({
      arn             = string
      name            = string
    }))
    region            = string
    security_groups   = list(string)
    ssh_key_name      = string
    stage             = string
    subnets           = list(string)
    vpc_id            = string
  })
}

variable "environment_internal" {
  description   = "Environment internal settings"
  type          = object({
    eks_version = string
  })
  default       = {
    eks_version = "1.32"
  }
}

variable "autoscaler_internal" {
  type           = object({
    chart        = object({
      name       = string
      repository = string
      version    = string
    })
    resources    = object({
      limits     = object({
        cpu      = number
        memory   = string
      })
      requests   = object({
        cpu      = number
        memory   = string
      })
    })
  })
  default        = {
    chart        = {
      name       = "cluster-autoscaler"
      repository = "https://kubernetes.github.io/autoscaler"
      version    = "9.29.0"
    }
    resources    = {
      limits     = {
        cpu      = 0.2
        memory   = "512Mi"
      }
      requests   = {
        cpu      = 0.1
        memory   = "128Mi"
      }
    }
  }
}

variable "nodes" {
  description                   = "EKS compute resource information"
  type                          = object({
    node_groups                 = object({
      cpu_memory_nodes          = object({
        ami_type                = string
        desired_size            = number
        ebs                     = object({
          delete_on_termination = bool
          encrypted             = bool
          iops                  = number
          kms_key_id            = string
          snapshot_id           = string
          throughput            = number
          volume_size           = string
          volume_type           = string
        })
        instance_types          = list(string)
        max_size                = number
        min_size                = number
      })
      cpu_only_nodes            = object({
        ami_type                = string
        desired_size            = number
        ebs                     = object({
          delete_on_termination = bool
          encrypted             = bool
          iops                  = number
          kms_key_id            = string
          snapshot_id           = string
          throughput            = number
          volume_size           = string
          volume_type           = string
        })
        instance_types          = list(string)
        max_size                = number
        min_size                = number
      })
      layout_nodes              = object({
        ami_type                = string
        desired_size            = number
        ebs                     = object({
          delete_on_termination = bool
          encrypted             = bool
          iops                  = number
          kms_key_id            = string
          snapshot_id           = string
          throughput            = number
          volume_size           = string
          volume_type           = string
        })
        instance_types          = list(string)
        max_size                = number
        min_size                = number
      })
      ranker_nodes              = object({
        ami_type                = string
        desired_size            = number
        ebs                     = object({
          delete_on_termination = bool
          encrypted             = bool
          iops                  = number
          kms_key_id            = string
          snapshot_id           = string
          throughput            = number
          volume_size           = string
          volume_type           = string
        })
        instance_types          = list(string)
        max_size                = number
        min_size                = number
      })
      summary_nodes             = object({
        ami_type                = string
        desired_size            = number
        ebs                     = object({
          delete_on_termination = bool
          encrypted             = bool
          iops                  = number
          kms_key_id            = string
          snapshot_id           = string
          throughput            = number
          volume_size           = string
          volume_type           = string
        })
        instance_types          = list(string)
        max_size                = number
        min_size                = number
      })
    })
  })
  default                       = {
    node_groups                 = {
      cpu_memory_nodes          = {
        ami_type                = "AL2023_x86_64_STANDARD"
        desired_size            = 1
        ebs                     = {
          delete_on_termination = true
          encrypted             = true
          iops                  = null
          kms_key_id            = null
          snapshot_id           = null
          throughput            = null
          volume_size           = 20
          volume_type           = "gp2"
        }
        instance_types          = ["m6a.xlarge"]
        max_size                = 4
        min_size                = 1
      }
      cpu_only_nodes            = {
        ami_type                = "AL2023_x86_64_STANDARD"
        desired_size            = 4
        ebs                     = {
          delete_on_termination = true
          encrypted             = true
          iops                  = null
          kms_key_id            = null
          snapshot_id           = null
          throughput            = null
          volume_size           = 20
          volume_type           = "gp2"
        }
        instance_types          = ["t3a.medium"]
        max_size                = 15
        min_size                = 4
      }
      layout_nodes              = {
        ami_type                = "AL2023_x86_64_NVIDIA"
        desired_size            = 1
        ebs                     = {
          delete_on_termination = true
          encrypted             = true
          iops                  = null
          kms_key_id            = null
          snapshot_id           = null
          throughput            = null
          volume_size           = 35
          volume_type           = "gp2"
        }
        instance_types          = ["g4dn.xlarge"]
        max_size                = 5
        min_size                = 1
      }
      ranker_nodes              = {
        ami_type                = "AL2023_x86_64_NVIDIA"
        desired_size            = 1
        ebs                     = {
          delete_on_termination = true
          encrypted             = true
          iops                  = null
          kms_key_id            = null
          snapshot_id           = null
          throughput            = null
          volume_size           = 75
          volume_type           = "gp2"
        }
        instance_types          = ["g4dn.2xlarge"]
        max_size                = 10
        min_size                = 1
      }
      summary_nodes             = {
        ami_type                = "AL2023_x86_64_NVIDIA"
        desired_size            = 1
        ebs                     = {
          delete_on_termination = true
          encrypted             = true
          iops                  = null
          kms_key_id            = null
          snapshot_id           = null
          throughput            = null
          volume_size           = 100
          volume_type           = "gp2"
        }
        instance_types          = ["g6e.xlarge"]
        max_size                = 10
        min_size                = 1
      }
    }
  }
}

variable "vpc" {
  description       = "VPC settings, for creating a VPC if needed"
  type              = object({
    cidr            = string
    private_subnets = list(string)
    public_subnets  = list(string)
  })
  default           = {
    cidr            = "10.0.0.0/16"
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  }
}