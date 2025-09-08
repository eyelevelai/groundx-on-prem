locals {
  sa_image_tag = var.summary_internal.api.image.tag != "latest" ? var.summary_internal.api.image.tag : var.deployment_type.tag
}

resource "helm_release" "summary_api_service" {
  count = local.create_summary ? 1 : 0

  name       = "${var.summary_internal.service}-api"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/summary/api/helm_chart"

  disable_openapi_validation = var.cluster.type == "openshift"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        cache         = "${local.cache_settings.addr} ${local.cache_settings.port}"
      }
      image           = {
        pull          = var.summary_internal.api.image.pull
        repository    = "${var.app_internal.repo_url}/${var.summary_internal.api.image.repository}${local.container_suffix}"
        tag           = local.sa_image_tag
      }
      nodeSelector    = {
        node          = local.node_assignment.summary_api
      }
      replicas        = {
        cooldown      = var.summary_resources.api.replicas.cooldown
        max           = local.replicas.summary.api.max
        min           = local.replicas.summary.api.min
        threshold     = var.summary_resources.api.replicas.threshold
      }
      resources       = var.summary_resources.api.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : var.deployment_type.user != null ? var.deployment_type.user : 1001
      }
      service         = {
        name          = "${var.summary_internal.service}-api"
        namespace     = var.app_internal.namespace
        version       = var.summary_internal.version
      }
    })
  ]

  timeout = 300
}