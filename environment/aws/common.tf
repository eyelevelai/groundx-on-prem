provider "kubernetes" {
  config_path = var.cluster.kube_config_path
}

provider "aws" {
  region = var.environment.region
}

provider "random" {}

resource "random_string" "name_suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
}

locals {
  cluster_name = "${var.cluster.prefix}_${random_string.name_suffix.result}"
}