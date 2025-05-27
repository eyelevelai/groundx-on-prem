locals {
  ingest_only  = var.cluster.search == false
  is_openshift = var.cluster.type == "openshift"

  container_suffix    = var.DEV == 1 ? "-dev" : ""
  op_container_suffix = var.cluster.internet_access ? (var.DEV == 1 ? "-dev" : "") : (var.DEV == 1 ? "-op-dev" : "-op")

  create_cache = var.cache_existing.addr == null || var.cache_existing.is_instance == null || var.cache_existing.port == null
  cache_settings = {
    addr        = coalesce(var.cache_existing.addr, "${var.cache_internal.service}.${var.app_internal.namespace}.svc.cluster.local")
    is_instance = coalesce(var.cache_existing.is_instance, var.cache_internal.is_instance)
    port        = coalesce(var.cache_existing.port, var.cache_internal.port)
  }

  create_metrics_cache = local.create_cache && var.cache_resources.metrics
  metrics_cache_settings = {
    addr        = var.cache_resources.metrics ? coalesce(var.cache_existing.addr, "${var.cache_internal.service}-${var.metrics_internal.service}.${var.app_internal.namespace}.svc.cluster.local") : local.cache_settings.addr
    is_instance = var.cache_resources.metrics ? coalesce(var.cache_existing.is_instance, var.cache_internal.is_instance) : local.cache_settings.is_instance
    port        = var.cache_resources.metrics ? coalesce(var.cache_existing.port, var.cache_internal.port) : local.cache_settings.port
  }

  create_database = var.db_existing.port == null || var.db_existing.ro == null || var.db_existing.rw == null
  db_endpoints = {
    port = coalesce(var.db_existing.port, var.db_internal.port)
    ro   = coalesce(var.db_existing.ro, "${var.db_internal.service}-cluster-pxc-db-haproxy.${var.app_internal.namespace}.svc.cluster.local")
    rw   = coalesce(var.db_existing.rw, "${var.db_internal.service}-cluster-pxc-db-haproxy.${var.app_internal.namespace}.svc.cluster.local")
  }

  db_settings = var.db_v2 != null ? var.db_v2 : {
    db_service_password   = var.db != null ? var.db.db_password : "password"
    db_service_username   = var.db != null ? var.db.db_username : "eyelevel"
    db_name               = var.db != null ? var.db.db_name : "eyelevel"
    db_create_db_password = var.db != null ? var.db.db_root_password : "password"
    db_create_db_username = "root"
  }

  create_file = var.file_existing.base_domain == null || var.file_existing.bucket == null || var.file_existing.password == null || var.file_existing.port == null || var.file_existing.ssl == null

  file_domain = coalesce(var.file.base_domain, "${var.file_internal.service}.${var.app_internal.namespace}.svc.cluster.local")

  file_settings = {
    base_domain   = coalesce(var.file_existing.base_domain, local.file_domain)
    bucket        = coalesce(var.file_existing.bucket, var.file.upload_bucket)
    dependency    = coalesce(var.file_existing.base_domain, "${var.file_internal.service}-tenant-hl.${var.app_internal.namespace}.svc.cluster.local")
    password      = coalesce(var.file_existing.password, var.file.password)
    port          = coalesce(var.file_existing.port, var.file_internal.port)
    ssl           = coalesce(var.file_existing.ssl, var.file_resources.ssl)
    username      = coalesce(var.file_existing.username, var.file.username)
  }

  create_graph = var.cluster.search && var.app.graph && (var.graph_existing.addr == null)
  graph_settings = {
    addr        = coalesce(var.graph_existing.addr, "${var.graph_internal.service}.${var.app_internal.namespace}.svc.cluster.local")
  }

  create_search = var.cluster.search && (var.search_existing.base_domain == null || var.search_existing.base_url == null || var.search_existing.port == null)
  search_settings = {
    base_domain = coalesce(var.search_existing.base_domain, "${var.search_internal.service}-cluster-master.${var.app_internal.namespace}.svc.cluster.local")
    base_url    = coalesce(var.search_existing.base_url, "https://${var.search_internal.service}-cluster-master.${var.app_internal.namespace}.svc.cluster.local:${var.search_internal.port}")
    port        = coalesce(var.search_existing.port, var.search_internal.port)
  }
  language_configs = contains(var.app.languages, "ko") ? merge({}, var.language_configs["ko"]) : merge({}, var.language_configs["en"])

  ranker_model = {
    throughput = try(
      [for model in local.language_configs.models : model.throughput if model.type == "ranker"][0],
      var.ranker_resources.inference.throughput,
    ),
    version = try(
      [for model in local.language_configs.models : model.version if model.type == "ranker"][0],
      "current",
    ),
    workers = try(
      [for model in local.language_configs.models : model.workers if model.type == "ranker"][0],
      var.ranker_resources.inference.workers,
    ),
  }

  create_stream = var.stream_existing.base_domain == null || var.stream_existing.base_url == null || var.stream_existing.port == null
  stream_settings = {
    base_domain = coalesce(var.stream_existing.base_domain, "${var.stream_internal.service}-cluster-kafka-bootstrap.${var.app_internal.namespace}.svc.cluster.local")
    port        = coalesce(var.stream_existing.port, var.stream_internal.port)
  }

  create_summary = (var.summary_existing.api_key == null || var.summary_existing.base_url == null) && coalesce(var.summary_existing.service_type, "on-prem") != "open-ai"

  summary_credentials = {
    api_key  = coalesce(var.summary_existing.api_key, var.admin.api_key)
    base_url = coalesce(var.summary_existing.base_url, "http://${var.summary_internal.service}-api.${var.app_internal.namespace}.svc.cluster.local")
    service_type = coalesce(var.summary_existing.service_type, "on-prem")
  }
}