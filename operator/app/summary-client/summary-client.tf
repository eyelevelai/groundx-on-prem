resource "helm_release" "summary_client_service" {
  name       = var.summary_client_internal.service
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/summary-client/helm_chart"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        groundx       = "${var.groundx_internal.service}.${var.app_internal.namespace}.svc.cluster.local"
      }
      image           = {
        pull          = var.summary_client_internal.image.pull
        repository    = "${var.app_internal.repo_url}/${var.summary_client_internal.image.repository}${local.container_suffix}"
        tag           = var.summary_client_internal.image.tag
      }
      nodeSelector    = {
        node          = local.node_assignment.summary_client
      }
      replicas        = {
        cooldown      = var.summary_client_resources.replicas.cooldown
        max           = local.replicas.summary_client.max
        min           = local.replicas.summary_client.min
        threshold     = var.summary_client_resources.replicas.threshold
      }
      resources       = var.summary_client_resources.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      service         = {
        name          = var.summary_client_internal.service
        namespace     = var.app_internal.namespace
        version       = var.summary_client_internal.version
      }
    })
  ]
}