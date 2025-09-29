variable "kube_config_path" {
  description = "Local path to kube config"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "Namespace for the GroundX app"
  type        = string
  default     = "eyelevel"
}