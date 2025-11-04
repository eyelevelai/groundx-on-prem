locals {
  ranker_config   = templatefile(
    "${local.module_path}/ranker/config.py.tpl", {
    cacheAddr     = local.cache_settings.addr
    cachePort     = local.cache_settings.port
    deviceType    = var.ranker_internal.inference.device
    metricsAddr   = local.metrics_cache_settings.addr
    metricsPort   = local.metrics_cache_settings.port
    rankerService = var.ranker_internal.service
    validAPIKey   = var.admin.api_key
    validUsername = var.admin.username
    workers       = local.ranker_model.workers
  })

  ranker_gunicorn = templatefile(
    "${local.module_path}/ranker/gunicorn_conf.py.tpl", {
    threads = var.ranker_resources.api.threads
    workers = var.ranker_resources.api.workers
  })

  ranker_supervisord = "${
    file(
      "${local.module_path}/ranker/supervisord.base.conf.tpl"
    )
  }\n${
    join(
      "\n",
      [
        for i in range(local.ranker_model.workers) : templatefile("${local.module_path}/ranker/supervisord.conf.tpl", {
          queues        = var.ranker_internal.inference.queues
          worker_number = i + 1
        })
      ]
    )
  }"
}

resource "kubernetes_config_map" "ranker_config_file" {
  metadata {
    name      = "ranker-config-py-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "config.py" = local.ranker_config
  }
}

resource "kubernetes_config_map" "ranker_gunicorn_conf_file" {
  metadata {
    name      = "ranker-gunicorn-conf-py-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "gunicorn_conf.py" = local.ranker_gunicorn
  }
}

resource "kubernetes_config_map" "ranker_supervisord_16gb_conf" {
  metadata {
    name      = "ranker-supervisord-16gb-conf-map"
    namespace = var.app_internal.namespace
  }

  data = {
    "supervisord.conf" = local.ranker_supervisord
  }
}