resource "kubernetes_service" "loadbalancer" {
  metadata {
    name = var.loadbalancer-name
  }

  spec {
    type = var.loadbalancer_type

    selector = {
      app = var.groundx_service
    }

    port {
      port        = var.loadbalancer_port
      target_port = var.loadbalancer_target_port
    }
  }
}
