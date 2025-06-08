locals {
  ldconfig_symlink = templatefile("${local.module_path}/config/ldconfig_symlink.sh", {})
}

resource "kubernetes_config_map" "ldconfig_symlink" {
  count = local.create_symlink ? 1 : 0

  metadata {
    name      = "ldconfig-symlink-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "ldconfig_symlink.sh" = local.ldconfig_symlink
  }
}