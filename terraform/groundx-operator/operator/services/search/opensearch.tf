resource "helm_release" "opensearch_operator" {
  count = local.create_search ? 1 : 0

  name       = "${var.search_internal.service}-operator"
  namespace  = var.app_internal.namespace

  chart      = var.search_internal.chart.name
  repository = var.search_internal.chart.url
  version    = var.search_internal.chart.version

  values = [
    yamlencode({
      clusterName = "${var.search_internal.service}-cluster"
      extraEnvs = [
        {
          name  = "OPENSEARCH_INITIAL_ADMIN_PASSWORD"
          value = var.search.root_password
        },
      ]
      global = {
        dockerRegistry = var.search_internal.image.repository
      }
      image = {
        repository = var.search_internal.image.name
        tag = var.search_internal.image.tag
      }
      majorVersion = var.search_internal.version
      nodeGroup   = "master"
      nodeSelector = {
        node = local.node_assignment.search
      }
      persistence = {
        enabled = true
        enableInitChown = false
        size = var.search_resources.pv_size
      }
      podSecurityContext = {
        fsGroup    = tonumber(local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1000) : 1000)
        runAsUser  = tonumber(local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1000) : 1000)
      }
      plugins = local.language_configs.search.plugins
      replicas = var.search_resources.replicas
      resources = var.search_resources.resources
      securityContext = {
        runAsNonRoot = true
        runAsUser    = tonumber(local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1000) : 1000)
      }
      singleNode = var.search_resources.replicas == 1
    })
  ]
}