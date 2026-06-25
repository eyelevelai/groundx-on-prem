data "aws_iam_policy" "efs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_security_group" "efs" {
  count = local.should_create && var.storage.driver == "efs" ? 1 : 0

  name        = "${local.cluster_name}-efs"
  description = "Allow EKS nodes to mount EFS for shared GroundX storage"
  vpc_id      = var.environment.vpc_id

  ingress {
    description     = "Allow NFS from EKS nodes"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = var.environment.security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment.stage
    Name        = "${local.cluster_name}-efs"
    Terraform   = "true"
  }
}

resource "aws_efs_file_system" "workspace" {
  count = local.should_create && var.storage.driver == "efs" ? 1 : 0

  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Environment = var.environment.stage
    Name        = "${local.cluster_name}-workspace"
    Terraform   = "true"
  }
}

resource "aws_efs_mount_target" "workspace" {
  count = local.should_create && var.storage.driver == "efs" ? length(var.environment.subnets) : 0

  file_system_id  = aws_efs_file_system.workspace[0].id
  security_groups = [aws_security_group.efs[0].id]
  subnet_id       = var.environment.subnets[count.index]
}

module "irsa_efs_csi" {
  count = local.should_create && var.storage.driver == "efs" ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEFSCSIRole-${local.cluster_name}"
  provider_url                  = module.eyelevel_eks[0].oidc_provider
  role_policy_arns              = [data.aws_iam_policy.efs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
}

resource "aws_eks_addon" "aws_efs_csi_driver" {
  count = local.should_create && var.storage.driver == "efs" ? 1 : 0

  depends_on = [
    module.eyelevel_eks,
    module.irsa_efs_csi,
    aws_efs_mount_target.workspace,
  ]

  cluster_name             = local.cluster_name
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = module.irsa_efs_csi[0].iam_role_arn
}
