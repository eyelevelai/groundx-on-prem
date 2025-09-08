locals {
  summary_config = templatefile(
    "${local.module_path}/summary/config.py.tpl", {
    cacheAddr      = local.cache_settings.addr
    cachePort      = local.cache_settings.port
    deviceType     = var.summary_internal.inference.device
    deviceUtilize  = var.summary_internal.inference.deviceUtilize
    metricsAddr    = local.metrics_cache_settings.addr
    metricsPort    = local.metrics_cache_settings.port
    summaryService = var.summary_internal.service
    validAPIKey    = var.admin.api_key
    validUsername  = var.admin.username
    workers        = var.summary_resources.inference.workers
  })

  summary_gunicorn = templatefile(
    "${local.module_path}/summary/gunicorn_conf.py.tpl", {
    threads = var.summary_resources.api.threads
    workers = var.summary_resources.api.workers
  })

  summary_supervisord = "${
    file(
      "${local.module_path}/summary/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(var.summary_resources.inference.workers) : templatefile("${local.module_path}/summary/supervisord.conf.tpl", {
          queues        = var.summary_internal.inference.queues
          threads       = var.summary_resources.inference.threads
          worker_number = i + 1
        })
      ]
    )
  }"
}

resource "kubernetes_config_map" "summary_config_file" {
  metadata {
    name      = "summary-config-py-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "config.py" = local.summary_config
  }
}

resource "kubernetes_config_map" "summary_gunicorn_conf_file" {
  metadata {
    name      = "summary-gunicorn-conf-py-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "gunicorn_conf.py" = local.summary_gunicorn
  }
}

resource "kubernetes_config_map" "summary_supervisord_24gb_conf" {
  metadata {
    name      = "summary-supervisord-24gb-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.summary_supervisord
  }
}