provider "aws" {
  region = var.region
}

# EKS IAM Role
resource "aws_iam_role" "eks" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public.id,
      aws_subnet.private.id
    ]

    # Configure public access to the cluster
    endpoint_public_access = var.internet_accessible

    # Configure private access to the cluster
    endpoint_private_access = !var.internet_accessible
  }

  tags = {
    Name = "my-eks-cluster"
  }
}

resource "aws_iam_role" "eks_node" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_s3" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_eks_node_group" "node_group_cpu" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "cpu-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  subnet_ids = [
    aws_subnet.public.id,
    aws_subnet.private.id
  ]

  instance_types = ["t3.micro"]

  labels = {
    "instance-type" = "cpu"
  }

  tags = {
    Name = "cpu-node-group"
  }
}

resource "aws_eks_node_group" "node_group_gpu" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "gpu-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  subnet_ids = [
    aws_subnet.public.id,
    aws_subnet.private.id
  ]

  instance_types = ["g5.xlarge"]

  labels = {
    "instance-type" = "gpu"
  }

  tags = {
    Name = "gpu-node-group"
  }
}
