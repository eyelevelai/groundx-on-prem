resource "helm_release" "metrics_service" {
  count = var.cluster.autoscale ? 1 : 0

  name       = var.metrics_internal.service
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/metrics/service"

  values = [
    yamlencode({
      busybox      = var.app_internal.busybox
      cluster      = var.cluster_arch
      debug        = var.app_internal.log_level == "debug" || var.app_internal.log_level == "trace"
      dependencies = {
        cache    = "${local.cache_settings.addr} ${local.cache_settings.port}"
        database = "${local.db_endpoints.ro} ${local.db_endpoints.port}"
      }
      image           = {
        pull          = var.metrics_internal.image.pull
        repository    = "${var.app_internal.repo_url}/${var.metrics_internal.image.repository}${local.container_suffix}"
        tag           = var.metrics_internal.image.tag
      }
      nodeSelector = {
        node = local.node_assignment.metrics
      }
      securityContext = {
        runAsUser  = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      service = {
        name      = var.metrics_internal.service
        namespace = var.app_internal.namespace
        version   = var.metrics_internal.version
      }
    })
  ]
}

resource "helm_release" "metrics_service_api" {
  count = var.cluster.autoscale ? 1 : 0

  name       = "${var.metrics_internal.service}-api"
  namespace  = var.app_internal.namespace

  depends_on = [helm_release.metrics_service]

  chart      = "${local.module_path}/metrics/api"

  values = [
    yamlencode({
      service = {
        name      = var.metrics_internal.service
        namespace = var.app_internal.namespace
      }
    })
  ]
}