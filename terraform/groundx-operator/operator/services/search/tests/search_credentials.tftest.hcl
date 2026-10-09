mock_provider "external" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  admin = {
    api_key  = "00000000-0000-0000-0000-000000000000"
    email    = "admin@example.com"
    password = "admin-password"
    username = "00000000-0000-0000-0000-000000000001"
  }
  cluster = {
    autoscale        = false
    environment      = "self"
    has_nvidia       = true
    internet_access  = true
    kube_config_path = "~/.kube/config"
    nodes = {
      cpu_memory  = "cpu"
      cpu_only    = "cpu"
      gpu_layout  = "gpu"
      gpu_ranker  = "gpu"
      gpu_summary = "gpu"
    }
    prefix = "test"
    pv = {
      name = "pv"
      type = "hostPath"
    }
    search = true
    throughput = {
      ingest = {
        baseline = 1
        max      = 1
      }
      search = {
        baseline = 1
        max      = 1
      }
    }
    type = "kubernetes"
  }
}

run "ingest_only_accepts_empty_search_passwords" {
  command = plan

  variables {
    cluster = merge(var.cluster, { search = false })
  }
}

run "search_enabled_rejects_empty_password" {
  command = plan

  variables {
    search = {
      index         = "prod-1"
      password      = ""
      root_password = "root-secret"
      user          = "eyelevel"
    }
  }

  expect_failures = [var.search]
}

run "search_enabled_rejects_placeholder_root_password" {
  command = plan

  variables {
    search = {
      index         = "prod-1"
      password      = "app-secret"
      root_password = "<opensearch-admin-password>"
      user          = "eyelevel"
    }
  }

  expect_failures = [var.search]
}

run "search_enabled_rejects_default_search_variable" {
  command = plan

  expect_failures = [var.search]
}

run "search_enabled_rejects_empty_root_password" {
  command = plan

  variables {
    search = {
      index         = "prod-1"
      password      = "app-secret"
      root_password = ""
      user          = "eyelevel"
    }
  }

  expect_failures = [var.search]
}

run "search_enabled_rejects_placeholder_password" {
  command = plan

  variables {
    search = {
      index         = "prod-1"
      password      = "<opensearch-password>"
      root_password = "root-secret"
      user          = "eyelevel"
    }
  }

  expect_failures = [var.search]
}

run "ingest_only_accepts_placeholder_search_passwords" {
  command = plan

  variables {
    cluster = merge(var.cluster, { search = false })
    search = {
      index         = "prod-1"
      password      = "<opensearch-password>"
      root_password = "<opensearch-admin-password>"
      user          = "eyelevel"
    }
  }
}

run "search_enabled_accepts_real_passwords" {
  command = plan

  variables {
    search = {
      index         = "prod-1"
      password      = "app-secret"
      root_password = "root-secret"
      user          = "eyelevel"
    }
  }
}
