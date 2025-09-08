locals {
  init_db = templatefile(
    "${local.module_path}/mysql/init-db.sql", {
    dbUserAPIKey = var.admin.api_key
    dbUserEmail  = var.admin.email
    dbUsername   = var.admin.username
    searchIndex  = var.search.index 
  })
}

resource "kubernetes_config_map" "init_database_file" {
  metadata {
    name      = "init-database-file"
    namespace = var.app_internal.namespace
  }

  data = {
    "init-db.sql" = local.init_db
  }
}