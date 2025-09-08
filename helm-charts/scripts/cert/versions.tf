terraform {
  required_version = ">= 1.0.0"
}

provider "kubernetes" {
  config_path = var.kube_config_path
}