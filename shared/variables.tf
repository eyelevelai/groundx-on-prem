# CLUSTER

variable "cluster" {
  description        = "Information about the Kubernetes cluster"
  type               = object({
    autoscale        = bool

    # hosting environment
    # valid values: aws, self, local
    environment      = string

    # set to true if the NVIDIA operator is already installed
    has_nvidia       = bool

    # has external internet access
    internet_access  = bool

    kube_config_path = string

    nodes            = object({
      cpu_memory     = string
      cpu_only       = string
      gpu_layout     = string
      gpu_ranker     = string
      gpu_summary    = string
    })

    # used on resource names
    prefix           = string

    pv               = object({
      name           = string
      type           = string
    })

    # whether search service should be deployed or not
    search           = bool

    throughput       = object({
      ingest         = object({
        baseline     = number
        max          = number
      })
      search         = object({
        baseline     = number
        max          = number
      })
    })

    # type of Kubernetes cluster
    # valid values: eks, openshift
    type             = string
  })
  default = {
    autoscale        = false
    environment      = "aws"
    has_nvidia       = false
    internet_access  = true
    kube_config_path = "~/.kube/config"
    nodes            = {
      cpu_memory     = "eyelevel-cpu-memory"
      cpu_only       = "eyelevel-cpu-only"
      gpu_layout     = "eyelevel-gpu-layout"
      gpu_ranker     = "eyelevel-gpu-ranker"
      gpu_summary    = "eyelevel-gpu-summary"
    }
    prefix           = "eyelevel"
    pv               = {
      name           = "eyelevel-pv"
      type           = "gp2"
    }
    search           = true
    throughput       = {
      ingest         = {
        baseline     = 9600
        max          = 9600
      }
      search         = {
        baseline     = 400000
        max          = 400000
      }
    }
    type             = "eks"
  }
}

variable "cluster_internal" {
  description      = "Kubernetes cluster internal settings"
  type             = object({
    nvidia         = object({
      name         = string
      namespace    = string
      chart        = object({
        name       = string
        repository = string
        version    = string
      })
    })
  })
  default          = {
    nvidia         = {
      name         = "nvidia-gpu-operator"
      namespace    = "nvidia-gpu-operator"
      chart        = {
        name       = "gpu-operator"
        repository = "https://helm.ngc.nvidia.com/nvidia"
        version    = "v25.3.0"
      }
    }
  }
}


# CACHE

variable "cache_resources" {
  description  = "Cache compute resource information"
  type         = object({
    metrics    = bool
    replicas   = number
    resources  = object({
      requests = object({
        cpu    = number
        memory = string
      })
    })
  })
  default      = {
    metrics    = true
    replicas   = 1
    resources  = {
      requests = {
        cpu    = 0.2
        memory = "512Mi"
      }
    }
  }
}


# DATABASE

variable "db_resources" {
  description    = "Database compute resource information"
  type           = object({
    proxy        = object({
      replicas   = number
      resources  = object({
        requests = object({
          cpu    = number
          memory = string
        })
      })
    })
    pv_size      = string
    replicas     = number
    resources    = object({
      requests   = object({
        cpu      = number
        memory   = string
      })
    })
  })
  default        = {
    proxy        = {
      replicas   = 1
      resources  = {
        requests = {
          cpu    = 0.6
          memory = "1Gi"
        }
      }
    }
    pv_size      = "20Gi"
    replicas     = 1
    resources    = {
      requests   = {
        cpu      = 0.6
        memory   = "512Mi"
      }
    }
  }
}


# FILE

variable "file_resources" {
  description           = "Database compute resource information"
  type                  = object({
    operator            = object({
      replicas          = number
    })
    pool_size           = string
    pool_servers        = number
    pool_server_volumes = number
    pv_path             = string
    resources           = object({
      requests          = object({
        cpu             = number
        memory          = string
      })
    })
    ssl                 = bool
  })
  default               = {
    operator            = {
      replicas          = 1
    }
    pool_size           = "50Gi"
    pool_servers        = 1
    pool_server_volumes = 1
    pv_path             = "/Users/USER/mnt/minio"
    resources           = {
      requests          = {
        cpu             = 0.1
        memory          = "256Mi"
      }
    }
    ssl                 = false
  }
}


# GRAPH

variable "graph_resources" {
  description  = "Graph compute resource information"
  type         = object({
    replicas   = number
    resources  = object({
      requests = object({
        cpu    = number
        memory = string
      })
    })
  })
  default      = {
    replicas   = 1
    resources  = {
      requests = {
        cpu    = 0.1
        memory = "256Mi"
      }
    }
  }
}


# GROUNDX

variable "groundx_resources" {
  description   = "GroundX compute resource information"
  type          = object({
    replicas    = object({
      cooldown  = number
      threshold = number
    })
    resources   = object({
      requests  = object({
        cpu     = number
        memory  = string
      })
    })
    throughput  = number
  })
  default       = {
    replicas    = {
      cooldown  = 60
      threshold = 8
    }
    resources   = {
      requests  = {
        cpu     = 0.1
        memory  = "128Mi"
      }
    }
    throughput  = 150000
  }
}


# LAYOUT

variable "layout_resources" {
  description     = "Layout compute resource information"
  type            = object({
    api           = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    correct       = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    inference     = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
          gpu     = number
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    load_balancer = object({
      internal    = bool
      port        = number
    })
    map           = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    ocr           = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    process       = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    save          = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
  })
  default         = {
    api           = {
      replicas    = {
        cooldown  = 60
        threshold = 5
      }
      resources   = {
        requests  = {
          cpu     = 0.1
          memory  = "256Mi"
        }
      }
      threads     = 2
      throughput  = 150000
      workers     = 2
    }
    correct       = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 1.5
          memory  = "1Gi"
        }
      }
      threads     = 1
      throughput  = 10000
      workers     = 1
    }
    inference     = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 0.5
          memory  = "2Gi"
          gpu     = 1
        }
      }
      threads     = 6
      throughput  = 120000
      workers     = 1
    }
    load_balancer = {
      internal    = true
      port        = 80
    }
    map           = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 0.1
          memory  = "256Mi"
        }
      }
      threads     = 1
      throughput  = 300000
      workers     = 1
    }
    ocr           = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 1
          memory  = "1Gi"
        }
      }
      threads     = 1
      throughput  = 10000
      workers     = 1
    }
    process       = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 0.1
          memory  = "1Gi"
        }
      }
      threads     = 1
      throughput  = 300000
      workers     = 1
    }
    save          = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 0.2
          memory  = "1Gi"
        }
      }
      threads     = 1
      throughput  = 300000
      workers     = 1
    }
  }
}


# LAYOUT WEBHOOK

variable "layout_webhook_resources" {
  description     = "Layout webhook compute resource information"
  type            = object({
    load_balancer = object({
      internal    = bool
      port        = number
    })
    replicas      = object({
      cooldown    = number
      threshold   = number
    })
    resources     = object({
      requests    = object({
        cpu       = number
        memory    = string
      })
    })
    throughput    = number
  })
  default         = {
    load_balancer = {
      internal    = true
      port        = 80
    }
    replicas      = {
      cooldown    = 60
      threshold   = 5
    }
    resources     = {
      requests    = {
        cpu       = 0.1
        memory    = "128Mi"
      }
    }
    throughput    = 1250000
  }
}


# PRE-PROCESS

variable "pre_process_resources" {
  description   = "Pre-Process compute resource information"
  type          = object({
    queue_size  = number
    replicas    = object({
      cooldown  = number
      threshold = number
    })
    resources   = object({
      requests  = object({
        cpu     = number
        memory  = string
      })
    })
    throughput  = number
  })
  default       = {
    queue_size  = 4
    replicas    = {
      cooldown  = 60
      threshold = 0.8
    }
    resources   = {
      requests  = {
        cpu     = 0.2
        memory  = "1Gi"
      }
    }
    throughput  = 9600
  }
}


# PROCESS

variable "process_resources" {
  description   = "Process compute resource information"
  type          = object({
    queue_size  = number
    replicas    = object({
      cooldown  = number
      threshold = number
    })
    resources   = object({
      requests  = object({
        cpu     = number
        memory  = string
      })
    })
    throughput  = number
  })
  default       = {
    queue_size  = 4
    replicas    = {
      cooldown  = 60
      threshold = 0.8
    }
    resources   = {
      requests  = {
        cpu     = 0.2
        memory  = "256Mi"
      }
    }
    throughput  = 11250
  }
}


# QUEUE

variable "queue_resources" {
  description   = "Queue compute resource information"
  type          = object({
    queue_size  = number
    replicas    = object({
      cooldown  = number
      threshold = number
    })
    resources   = object({
      requests  = object({
        cpu     = number
        memory  = string
      })
    })
    throughput  = number
  })
  default       = {
    queue_size  = 4
    replicas    = {
      cooldown  = 60
      threshold = 0.8
    }
    resources   = {
      requests  = {
        cpu     = 0.1
        memory  = "128Mi"
      }
    }
    throughput  = 11250
  }
}


# RANKER

variable "ranker_resources" {
  description     = "Ranker compute resource information"
  type            = object({
    api           = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    inference     = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
          gpu     = number
        })
      })
      throughput  = number
      workers     = number
    })
  })
  default         = {
    api           = {
      replicas    = {
        cooldown  = 60
        threshold = 5
      }
      resources   = {
        requests  = {
          cpu     = 0.1
          memory  = "128Mi"
        }
      }
      threads     = 3
      throughput  = 1000000
      workers     = 1
    }
    inference     = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 1.5
          memory  = "1Gi"
          gpu     = 1
        }
      }
      throughput  = 400000
      workers     = 14
    }
  }
}


# SEARCH

variable "search_resources" {
  description  = "Search compute resource information"
  type         = object({
    pv_size    = string
    replicas   = number
    resources  = object({
      requests = object({
        cpu    = number
        memory = string
      })
    })
  })
  default      = {
    pv_size    = "20Gi"
    replicas   = 1
    resources  = {
      requests = {
        cpu    = 0.2
        memory = "512Mi"
      }
    }
  }
}


# STREAM

variable "stream_resources" {
  description       = "Stream compute resource information"
  type              = object({
    nodepool        = object({
      replicas      = number
      storage       = string
    })
    operator        = object({
      replicas      = number
    })
    resources       = object({
      requests      = object({
        cpu         = string
        memory      = string
      })
    })
    retention_bytes = number
    segment_bytes   = number
    service         = object({
      replicas      = number
      storage       = string
    })
  })
  default           = {
    nodepool        = {
      replicas      = 1
      storage       = "5Gi"
    }
    operator        = {
      replicas      = 1
    }
    resources       = {
      requests      = {
        cpu         = "200m"
        memory      = "512Mi"
      }
    }
    retention_bytes = 1073741824
    segment_bytes   = 1073741824
    service         = {
      replicas      = 1
      storage       = "10Gi"
    }
  }
}


# SUMMARY

variable "summary_resources" {
  description     = "Summary compute resource information"
  type            = object({
    api           = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    inference     = object({
      replicas    = object({
        cooldown  = number
        threshold = number
      })
      resources   = object({
        requests  = object({
          cpu     = number
          memory  = string
          gpu     = number
        })
      })
      threads     = number
      throughput  = number
      workers     = number
    })
    load_balancer = object({
      internal    = bool
      port        = number
    })
  })
  default         = {
    api           = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 0.1
          memory  = "256Mi"
        }
      }
      threads     = 4
      throughput  = 9600
      workers     = 1
    }
    inference     = {
      replicas    = {
        cooldown  = 60
        threshold = 0.8
      }
      resources   = {
        requests  = {
          cpu     = 0.5
          memory  = "1Gi"
          gpu     = 1
        }
      }
      threads     = 1
      throughput  = 4800
      workers     = 1
    }
    load_balancer = {
      internal    = true
      port        = 80
    }
  }
}


# SUMMARY-CLIENT

variable "summary_client_resources" {
  description   = "Summary client compute resource information"
  type          = object({
    replicas    = object({
      cooldown  = number
      threshold = number
    })
    resources   = object({
      requests  = object({
        cpu     = number
        memory  = string
      })
    })
    throughput  = number
    workers     = number
  })
  default       = {
    replicas    = {
      cooldown  = 60
      threshold = 0.8
    }
    resources   = {
      requests  = {
        cpu     = 0.1
        memory  = "512Mi"
      }
    }
    throughput  = 9600
    workers     = 3
  }
}


# THROUGHPUT

variable "throughput" {
  description         = "Baseline and max throughputs for services, in tokens per minute"
  type                = object({
    conversions       = object({
      document        = object({
        tpm           = number
      })
      page            = object({
        tpm           = number
      })
      summaryRequests = object({
        tpm           = number
      })
    })
    services          = object({
      layout          = object({
        inference     = number
        map           = number
        ocr           = number
        process       = number
        save          = number
      })
      pre_process     = object({
        queue         = number
      })
      process         = object({
        queue         = number
      })
      queue           = object({
        queue         = number
      })
      ranker          = object({
        inference     = number
      })
      summary         = object({
        api           = number
        inference     = number
      })
      summary_client  = object({
        api           = number
      })
      upload          = object({
        queue         = number
      })
    })
  })
  default             = {
    conversions       = {
      document        = {
        tpm           = 12500
      }
      page            = {
        tpm           = 500
      }
      summaryRequests = {
        tpm           = 625
      }
    }
    services          = {
      layout          = {
        inference     = 240 * 500
        map           = 500
        ocr           = 500
        process       = 500
        save          = 500
      }
      pre_process     = {
        queue         = 6
      }
      process         = {
        queue         = 9
      }
      queue           = {
        queue         = 9
      }
      ranker          = {
        inference     = 0
      }
      summary         = {
        api           = 9600
        inference     = 3200
      }
      summary_client  = {
        api           = 9600
      }
      upload          = {
        queue         = 120
      }
    }
  }
}


# UPLOAD

variable "upload_resources" {
  description   = "Upload compute resource information"
  type          = object({
    queue_size  = number
    replicas    = object({
      cooldown  = number
      threshold = number
    })
    resources   = object({
      requests  = object({
        cpu     = number
        memory  = string
      })
    })
    throughput  = number
  })
  default       = {
    queue_size  = 4
    replicas    = {
      cooldown  = 60
      threshold = 0.8
    }
    resources   = {
      requests  = {
        cpu     = 0.1
        memory  = "128Mi"
      }
    }
    throughput  = 150000
  }
}
