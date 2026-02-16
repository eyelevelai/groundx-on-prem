resource "aws_iam_policy" "autoscaler_policy" {
  count = var.cluster.autoscale ? 1 : 0

  name   = "cluster-autoscaler-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ],
        Resource = "*",
      },
      {
        "Effect": "Allow",
        "Action": [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        "Resource": ["*"]
      }
    ],
  })
}

module "irsa_autoscaler" {
  count = var.cluster.autoscale ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFAutoscalerRole-${local.cluster_name}"
  provider_url                  = module.eyelevel_eks[0].oidc_provider
  role_policy_arns              = [aws_iam_policy.autoscaler_policy[0].arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:${var.cluster.prefix}-ca-aws-cluster-autoscaler"]
}

resource "aws_iam_role_policy_attachment" "autoscaler_policy_attachment" {
  count = var.cluster.autoscale ? 1 : 0

  role       = module.irsa_autoscaler[0].iam_role_name
  policy_arn = aws_iam_policy.autoscaler_policy[0].arn
}

resource "helm_release" "cluster_autoscaler" {
  count = local.should_create && var.cluster.autoscale ? 1 : 0

  depends_on = [null_resource.wait_for_eks]

  name         = "${var.cluster.prefix}-ca"
  namespace    = "kube-system"

  chart      = "${var.autoscaler_internal.chart.name}"
  repository = "${var.autoscaler_internal.chart.repository}"
  version    = "${var.autoscaler_internal.chart.version}"

  set = [
    {
      name  = "autoDiscovery.clusterName"
      value = "${local.cluster_name}"
    },
    {
      name  = "awsRegion"
      value = "${var.environment.region}"
    },
    {
      name  = "cloudProvider"
      value = "aws"
    },
    {
      name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = "${module.irsa_autoscaler[0].iam_role_arn}"
    },
    {
      name  = "extraArgs.balance-similar-node-groups"
      value = "true"
    },
    {
      name  = "extraArgs.skip-nodes-with-local-storage"
      value = "false"
    },
    {
      name  = "resources.limits.cpu"
      value = "${var.autoscaler_internal.resources.limits.cpu}"
    },
    {
      name  = "resources.limits.memory"
      value = "${var.autoscaler_internal.resources.limits.memory}"
    },
    {
      name  = "resources.requests.cpu"
      value = "${var.autoscaler_internal.resources.requests.cpu}"
    },
    {
      name  = "resources.requests.memory"
      value = "${var.autoscaler_internal.resources.requests.memory}"
    },
  ]
}