resource "helm_release" "neo4j" {
  count = local.create_graph ? 1 : 0

  name       = var.graph_internal.service
  namespace  = var.app_internal.namespace

  chart      = var.graph_internal.chart.name
  repository = var.graph_internal.chart.url
  version    = var.graph_internal.chart.version

  values = [
    yamlencode({
      neo4j = {
        acceptLicenseAgreement = "yes"
        edition      = "eval"
        name         = var.graph_internal.service
        password     = "test"
      }
      nodeSelector = {
        node = local.node_assignment.graph
      }
      securityContext = {
        runAsUser  = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.UID, 1001) : 1001
        runAsGroup = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
        fsGroup    = local.is_openshift ? coalesce(data.external.get_uid_gid[0].result.GID, 1001) : 1001
      }
      volumes      = {
        data       = {
          mode     = "defaultStorageClass"
        }
      }
    })
  ]
}