locals {
  config_models = templatefile("${local.module_path}/config/config_models.py.tpl", {
    models = jsonencode(local.language_configs.models)
  })
}

resource "kubernetes_config_map" "config_models" {
  metadata {
    name      = "config-models-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "config_models.py" = local.config_models
  }
}