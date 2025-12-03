locals {
  cpu_memory_label = (
    var.node_labels.cpu_memory != null && var.node_labels.cpu_memory != ""
  ) ? var.node_labels.cpu_memory : var.cluster.nodes.cpu_memory

  cpu_only_label = (
    var.node_labels.cpu_only != null && var.node_labels.cpu_only != ""
  ) ? var.node_labels.cpu_only : var.cluster.nodes.cpu_only

  gpu_layout_label = (
    var.node_labels.gpu_layout != null && var.node_labels.gpu_layout != ""
  ) ? var.node_labels.gpu_layout : var.cluster.nodes.gpu_layout

  gpu_ranker_label = (
    var.node_labels.gpu_ranker != null && var.node_labels.gpu_ranker != ""
  ) ? var.node_labels.gpu_ranker : var.cluster.nodes.gpu_ranker

  gpu_summary_label = (
    var.node_labels.gpu_summary != null && var.node_labels.gpu_summary != ""
  ) ? var.node_labels.gpu_summary : var.cluster.nodes.gpu_summary

  node_assignment = {
    cache             = local.cpu_only_label
    db                = local.cpu_only_label
    file              = local.cpu_only_label
    graph             = local.cpu_only_label
    groundx           = local.cpu_only_label
    layout_api        = local.cpu_only_label
    layout_correct    = local.cpu_memory_label
    layout_inference  = local.gpu_layout_label
    layout_map        = local.cpu_only_label
    layout_ocr        = local.cpu_memory_label
    layout_process    = local.cpu_memory_label
    layout_save       = local.cpu_memory_label
    layout_webhook    = local.cpu_only_label
    metrics           = local.cpu_only_label
    pre_process       = local.cpu_memory_label
    process           = local.cpu_only_label
    queue             = local.cpu_only_label
    ranker_api        = local.cpu_only_label
    ranker_inference  = local.gpu_ranker_label
    summary_api       = local.cpu_only_label
    summary_inference = local.gpu_summary_label
    summary_client    = local.cpu_only_label
    search            = local.cpu_only_label
    stream            = local.cpu_only_label
    upload            = local.cpu_only_label
  }
}