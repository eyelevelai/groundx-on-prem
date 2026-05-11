output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = length(module.eyelevel_eks) > 0 ? module.eyelevel_eks[0].cluster_endpoint : "(not created)"
}

output "storage_driver" {
  description = "Selected Kubernetes storage driver"
  value       = var.storage.driver
}

output "storage_class_name" {
  description = "Kubernetes storage class name for GroundX persistent volumes"
  value       = var.cluster.pv.name
}

output "storage_access_mode" {
  description = "Kubernetes PVC access mode supported by the selected storage driver"
  value       = var.storage.driver == "efs" ? "ReadWriteMany" : "ReadWriteOnce"
}

output "efs_file_system_id" {
  description = "EFS file system ID when storage.driver is efs"
  value       = var.storage.driver == "efs" && length(aws_efs_file_system.workspace) > 0 ? aws_efs_file_system.workspace[0].id : ""
}
