provider "helm" {
  kubernetes = {
    config_path = var.cluster.kube_config_path
  }
}