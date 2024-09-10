resource "kubernetes_service" "loadbalancer" {
  metadata {
    name = var.service_name
  }

  spec {
    type = var.service_type

    selector = {
      app = var.app_selector
    }

    port {
      port        = var.service_port
      target_port = var.target_port
    }
  }
}
