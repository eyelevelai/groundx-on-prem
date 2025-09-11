output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = length(module.eyelevel_eks) > 0 ? module.eyelevel_eks[0].cluster_endpoint : "(not created)"
}