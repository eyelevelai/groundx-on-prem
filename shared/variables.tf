# CLUSTER

variable "cluster" {
  description = "Information about the Kubernetes cluster"
  type        = object({
    # hosting environment
    # valid values: aws, self
    environment      = string

    # set to true if the NVIDIA operator is already installed
    has_nvidia       = bool

    # has external internet access
    internet_access  = bool

    kube_config_path = string
    prefix           = string

    # admin or developer
    role             = string

    # whether search service should be deployed or not
    search           = bool

    # type of Kubernetes cluster
    # valid values: eks, openshift
    type             = string
  })
  default = {
    environment      = "aws"
    has_nvidia       = false
    internet_access  = true
    kube_config_path = "~/.kube/config"
    prefix           = "eyelevel"
    role             = "admin"
    search           = true
    type             = "eks"
  }
  validation {
    condition        = var.cluster.role == "admin"
    error_message    = "You must be an admin of this cluster to install the operator"
  }
}

variable "cluster_internal" {
  description      = "Kubernetes cluster internal settings"
  type             = object({
    nodes          = object({
      cpu_memory   = string
      cpu_only     = string
      gpu_layout   = string
      gpu_ranker   = string
      gpu_summary  = string
    })
    nvidia         = object({
      driver       = string
      name         = string
      namespace    = string
      chart        = object({
        name       = string
        repository = string
        version    = string
      })
    })
    pv             = object({
      name         = string
      type         = string
    })
  })
  default          = {
    nodes          = {
      cpu_memory   = "eyelevel-cpu-memory"
      cpu_only     = "eyelevel-cpu-only"
      gpu_layout   = "eyelevel-gpu-layout"
      gpu_ranker   = "eyelevel-gpu-ranker"
      gpu_summary  = "eyelevel-gpu-summary"
    }
    nvidia         = {
      driver       = "550.54.15"
      name         = "nvidia-gpu-operator"
      namespace    = "nvidia-gpu-operator"
      chart        = {
        name       = "gpu-operator"
        repository = "https://helm.ngc.nvidia.com/nvidia"
        version    = "v23.9.2"
      }
    }
    pv             = {
      name         = "eyelevel-ebs-gp3"
      type         = "gp3"
    }
  }
}