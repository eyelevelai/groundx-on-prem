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


data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

locals {
  app_irsa_s3_bucket_arns = [for b in coalesce(var.app_irsa_s3_buckets, []) : "arn:${data.aws_partition.current.partition}:s3:::${b}"]
  app_irsa_sqs_queue_arns = [for q in coalesce(var.app_irsa_sqs_queues, []) : "arn:${data.aws_partition.current.partition}:sqs:${var.environment.region}:${data.aws_caller_identity.current.account_id}:${q}"]

  app_irsa_s3_statements = var.app_irsa_s3_buckets == null ? [
    { sid = "FullS3", actions = ["s3:*"], resources = ["*"] },
    ] : length(var.app_irsa_s3_buckets) == 0 ? [] : [
    {
      sid       = "S3Buckets"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = local.app_irsa_s3_bucket_arns
    },
    {
      sid       = "S3Objects"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging", "s3:AbortMultipartUpload"]
      resources = [for arn in local.app_irsa_s3_bucket_arns : "${arn}/*"]
    },
  ]

  app_irsa_sqs_statements = var.app_irsa_sqs_queues == null ? [
    { sid = "FullSqs", actions = ["sqs:*"], resources = ["*"] },
    ] : length(var.app_irsa_sqs_queues) == 0 ? [] : [
    {
      sid       = "SqsQueues"
      actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
      resources = local.app_irsa_sqs_queue_arns
    },
  ]

  app_irsa_statements = concat(local.app_irsa_s3_statements, local.app_irsa_sqs_statements)
  app_irsa_policy_count = length(local.app_irsa_statements) > 0 ? 1 : 0
}

# Broad admin policy for S3 and SQS (Option 2)
data "aws_iam_policy_document" "s3_sqs_admin" {
  count = local.app_irsa_policy_count

  dynamic "statement" {
    for_each = local.app_irsa_statements
    content {
      sid       = statement.value.sid
      effect    = "Allow"
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "s3_sqs_admin" {
  count  = local.app_irsa_policy_count
  name   = "${local.app_ns}-${local.sa_name}-s3-sqs-admin"
  policy = data.aws_iam_policy_document.s3_sqs_admin[0].json
}

resource "aws_iam_role_policy_attachment" "attach_admin" {
  count      = local.app_irsa_policy_count
  role       = aws_iam_role.app_irsa.name
  policy_arn = aws_iam_policy.s3_sqs_admin[0].arn
}

moved {
  from = aws_iam_policy.s3_sqs_admin
  to   = aws_iam_policy.s3_sqs_admin[0]
}

moved {
  from = aws_iam_role_policy_attachment.attach_admin
  to   = aws_iam_role_policy_attachment.attach_admin[0]
}
