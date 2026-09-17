mock_provider "aws" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "null" {}
mock_provider "random" {}

variables {
  environment = {
    cluster_role_arns = []
    region            = "us-west-2"
    security_groups   = []
    ssh_key_name      = "test"
    stage             = "test"
    subnets           = ["subnet-test"]
    vpc_id            = "vpc-test"
  }
}

override_data {
  target = data.aws_iam_policy_document.app_irsa_trust
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.s3_sqs_admin
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

override_module {
  target = module.eyelevel_eks
  outputs = {
    cluster_endpoint  = "https://example.invalid"
    oidc_provider     = "oidc.eks.us-west-2.amazonaws.com/id/test"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/test"
  }
}

override_module {
  target = module.irsa_autoscaler
  outputs = {
    iam_role_arn = "arn:aws:iam::123456789012:role/test-autoscaler"
  }
}

override_module {
  target = module.irsa_efs_csi
  outputs = {
    iam_role_arn = "arn:aws:iam::123456789012:role/test-efs-csi"
  }
}

run "configured_version_resolves_to_the_configured_value" {
  command = plan

  variables {
    environment_internal = {
      eks_version = "1.36"
    }
  }

  assert {
    condition     = var.environment_internal.eks_version == "1.36"
    error_message = "The configured version key must resolve to the configured value."
  }
}

run "unset_version_resolves_to_null" {
  command = plan

  variables {
    environment_internal = {}
  }

  assert {
    condition     = var.environment_internal.eks_version == null
    error_message = "An unset version key must resolve to null, not any implicit default."
  }
}
