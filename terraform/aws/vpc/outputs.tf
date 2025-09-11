output "ssh_security_group" {
  description = "Security group ID that allows SSH from VPC subnets only, add this to env.tfvars to enable SSH"
  value       = aws_security_group.ssh_access.id
}

output "subnets" {
  description = "Subnets for EyeLevel VPC, add these to env.tfvars"
  value       = module.eyelevel_vpc.private_subnets
}

output "vpc_id" {
  description = "VPC ID for EyeLevel VPC, add this to env.tfvars"
  value       = module.eyelevel_vpc.vpc_id
}