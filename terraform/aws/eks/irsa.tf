locals {
  app_ns  = "eyelevel"
  sa_name = "s3-sqs-worker"
}

data "aws_iam_policy_document" "app_irsa_trust" {
  statement {
    effect        = "Allow"
    actions       = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eyelevel_eks[0].oidc_provider_arn]
    }
    condition {
      test        = "StringEquals"
      variable    = "${module.eyelevel_eks[0].oidc_provider}:sub"
      values      = ["system:serviceaccount:${local.app_ns}:${local.sa_name}"]
    }
    condition {
      test        = "StringEquals"
      variable    = "${module.eyelevel_eks[0].oidc_provider}:aud"
      values      = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_irsa" {
  name               = "${local.app_ns}-${local.sa_name}-irsa"
  assume_role_policy = data.aws_iam_policy_document.app_irsa_trust.json
}


# Broad admin policy for S3 and SQS (Option 2)
data "aws_iam_policy_document" "s3_sqs_admin" {
  statement {
    sid       = "FullS3"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }
  statement {
    sid       = "FullSqs"
    effect    = "Allow"
    actions   = ["sqs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "s3_sqs_admin" {
  name   = "${local.app_ns}-${local.sa_name}-s3-sqs-admin"
  policy = data.aws_iam_policy_document.s3_sqs_admin.json
}

resource "aws_iam_role_policy_attachment" "attach_admin" {
  role       = aws_iam_role.app_irsa.name
  policy_arn = aws_iam_policy.s3_sqs_admin.arn
}
