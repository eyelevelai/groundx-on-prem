locals {
  values_base      = file("${path.module}/values/values-base.yaml")

  values_overlay   = (
    var.cluster_type == "aks" ? file("${path.module}/values/values-${var.cluster_type}.yaml") : ""
  )

  values_list      = compact([local.values_base, local.values_overlay])
}

resource "helm_release" "gpu_operator" {
  name             = var.name
  namespace        = var.namespace

  repository       = var.chart.repository
  chart            = var.chart.name
  version          = var.chart.version

  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  reset_values     = true
  replace          = true

  values           = local.values_list
}