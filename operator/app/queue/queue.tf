resource "helm_release" "queue_service" {
  name       = var.queue_internal.service
  namespace  = var.app_internal.namespace
  chart      = "${local.module_path}/queue/helm_chart"

  values = [
    yamlencode({
      busybox         = var.app_internal.busybox
      cluster         = var.cluster_arch
      dependencies    = {
        groundx       = "${var.groundx_internal.service}.${var.app_internal.namespace}.svc.cluster.local"
      }
      image           = {
        pull          = var.queue_internal.image.pull
        repository    = "${var.app_internal.repo_url}/${var.queue_internal.image.repository}${local.container_suffix}"
        tag           = var.queue_internal.image.tag
      }
      nodeSelector    = {
        node          = local.node_assignment.queue
      }
      replicas        = {
        cooldown      = var.queue_resources.replicas.cooldown
        max           = local.replicas.queue.max
        min           = local.replicas.queue.min
        threshold     = var.queue_resources.replicas.threshold
      }
      resources       = var.queue_resources.resources
      securityContext = {
        runAsUser     = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup       = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      service         = {
        name          = var.queue_internal.service
        namespace     = var.app_internal.namespace
        version       = var.queue_internal.version
      }
    })
  ]
}