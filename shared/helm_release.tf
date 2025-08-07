terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 6.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = var.cluster.kube_config_path
  }
}