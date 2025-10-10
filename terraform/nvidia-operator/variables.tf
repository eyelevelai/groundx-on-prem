variable "chart" {
  description = "Helm chart information for the NVIDIA GPU operator"
  type        = object({
    name       = string
    repository = string
    version    = string
  })
  default     = {
    name       = "gpu-operator"
    repository = "https://helm.ngc.nvidia.com/nvidia"
    version    = "v25.3.4"
  }
}

variable "cluster_type" {
  description = "Cluster type to select values overlay (eks|aks|other)"
  type        = string
  default     = "eks"
}

variable "kube_config_path" {
  description = "Local path to kube config"
  type        = string
  default     = "~/.kube/config"
}

variable "name" {
  description = "Helm release name for the NVIDIA GPU operator"
  type        = string
  default     = "nvidia-gpu-operator"
}

variable "namespace" {
  description = "Namespace to install the operator"
  type        = string
  default     = "nvidia-gpu-operator"
}
