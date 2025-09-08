terraform {
  required_version = ">= 1.0.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kube_config_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kube_config_path
  }
}