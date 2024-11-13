resource "helm_release" "summary_api_service" {
  count = local.create_summary ? 0 : 0

  name       = "${var.summary_internal.service}-api-cluster"
  namespace  = var.app_internal.namespace

  chart      = "${local.module_path}/summary/api/helm_chart"

  values = [
    yamlencode({
      dependencies    = {
        cache         = "${local.cache_settings.addr} ${local.cache_settings.port}"
      }
      image           = var.summary_internal.api.image
      nodeSelector    = {
        node          = var.cluster_internal.nodes.cpu_only
      }
      replicas        = var.summary_resources.api.replicas
      resources       = var.summary_resources.api.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
      }
      service         = {
        name          = "${var.summary_internal.service}-api"
        namespace     = var.app_internal.namespace
        version       = var.summary_internal.version
      }
    })
  ]
}