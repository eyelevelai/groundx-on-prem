resource "aws_security_group" "ssh_access" {
  depends_on  = [module.eyelevel_vpc]

  name        = "allow_ssh_vpc_only"
  description = "Security group that allows SSH from VPC subnets only"
  vpc_id      = module.eyelevel_vpc.vpc_id

  ingress {
    description = "Allow SSH from VPC subnets only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat(var.vpc.private_subnets, var.vpc.public_subnets)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_vpc_only"
  }
}