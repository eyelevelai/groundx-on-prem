variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  default     = "10.0.2.0/24"
}

variable "internet_accessible" {
  description = "Whether the EKS cluster should be accessible via the internet"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "eyelevel-on-prem"
}

variable "region" {
  description = "AWS region"
  default     = "us-west-2"
  type        = string
}
