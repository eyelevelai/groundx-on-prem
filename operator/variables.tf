# OPERATOR

variable "admin" {
  description = "Administrator account information for EyeLevel"
  type        = object({
    # should be a UUID, generate using uuid.sh
    api_key   = string

    email     = string
    password  = string

    # should be a UUID, generate using uuid.sh
    username  = string
  })
}

variable "app" {
  description       = "EyeLevel application information"
  type              = object({
    graph           = bool
    languages       = list(string)
  })
  default           = {
    graph           = false
    languages       = ["en"]
  }
}

variable "app_internal" {
  description    = "EyeLevel application internal information (do not change)"
  type           = object({
    busybox      = object({
      pull       = string
      repository = string
      tag        = string
    })
    log_level    = string
    namespace    = string
    repo_url     = string
  })
  default        = {
    busybox      = {
      pull       = "Always"
      repository = "public.ecr.aws/c9r4x6y5/eyelevel/busybox"
      tag        = "latest"
    }
    log_level    = "info"
    namespace    = "eyelevel"
    repo_url     = "public.ecr.aws/c9r4x6y5/eyelevel"
  }
}

variable "engines" {
  description          = "Completion engine configurations"
  type                 = list(
    object(
      {
        apiKey         = string
        baseURL        = string
        engineID       = string
        maxInputTokens = number
        maxRequests    = number
        maxTokens      = number
        requestLimit   = number
        type           = string
        vision         = bool
      }
    )
  )
  default              = [
    {
      apiKey           = null
      baseURL          = null
      engineID         = "gemma-3-4b-it"
      maxInputTokens   = 2000
      maxRequests      = 4
      maxTokens        = 10000000000
      requestLimit     = 4
      type             = null
      vision           = true
    }
  ]
}


# CACHE

variable "cache_existing" {
  description    = "Cache settings, if using an existing Redis cache outside of Kubernetes"
  type           = object({
    addr         = string
    is_instance  = bool
    port         = number
  })
  default        = {
    addr         = null
    is_instance  = null
    port         = null
  }
}

variable "cache_internal" {
  description        = "Redis internal settings"
  type               = object({
    image            = object({
      pull           = string
      repository     = string
      tag            = string
    })
    is_instance      = bool
    mount_path       = string
    operator_version = string
    port             = number
    service          = string
    version          = string
  })
  default            = {
    image            = {
      pull           = "Always"
      repository     = "redis"
      tag            = "latest"
    }
    is_instance      = true
    mount_path       = "/mnt/redis"
    operator_version = "v7.4.6-2"
    port             = 6379
    service          = "redis"
    version          = "6.1"
  }
}


# DASHBOARD

variable "dashboard_internal" {
  description = "Web dashboard internal settings"
  type        = object({
    service   = string
  })
  default     = {
    service   = "dashboard"
  }
}


# DATABASE

variable "db" {
  description        = "Legacy Database service information (deprecated)"
  type               = object({
    db_name          = string
    db_password      = string
    db_root_password = string
    db_username      = string
  })
  default            = null
}

variable "db_v2" {
  description             = "Database service information (as of db v1.0.0)"
  type                    = object({
    db_create_db_password = string
    db_create_db_username = string
    db_name               = string
    db_service_password   = string
    db_service_username   = string
  })
  default                 = {
    # this user must be able to create the eyelevel database and db_service_username
    db_create_db_password = "password"
    db_create_db_username = "root"

    # name of the database created
    db_name               = "eyelevel"

    # this user is created by db_create_db_username and assumed by the pods.
    db_service_password   = "password" 
    db_service_username   = "eyelevel"
  }
}

variable "db_existing" {
  description = "Database endpoint settings, if using an existing database outside of Kubernetes"
  type        = object({
    port      = number
    ro        = string
    rw        = string
  })
  default     = {
    port      = null
    ro        = null
    rw        = null
  }
}

variable "db_internal" {
  description             = "Database internal settings"
  type                    = object({
    backup                = bool
    chart                 = object({
      db                  = object({
        name              = string
        version           = string
      })
      operator            = object({
        name              = string
        version           = string
      })
      repository          = string
    })
    disable_unsafe_checks = bool
    ip_type               = string
    logcollector_enable   = bool
    pmm_enable            = bool
    port                  = number
    service               = string
    version               = string
  })
  default                 = {
    backup                = false
    chart                 = {
      db                  = {
        name              = "pxc-db"
        version           = "1.15.1"
      }
      operator            = {
        name              = "pxc-operator"
        version           = "1.15.1"
      }
      repository          = "https://percona.github.io/percona-helm-charts"
    }
    disable_unsafe_checks = true
    ip_type               = "ClusterIP"
    logcollector_enable   = false
    pmm_enable            = false
    port                  = 3306
    service               = "mysql"
    version               = "8.0"
  }
}


# FILE

variable "file" {
  description     = "Database service information"
  type            = object({
    base_domain   = string
    password      = string
    upload_bucket = string
    username      = string
  })
  default         = {
    base_domain   = null
    password      = "minio123"
    upload_bucket = "eyelevel"
    username      = "minio"
  }
}

variable "file_existing" {
  description   = "MinIO settings, if using an existing MinIO instance outside of Kubernetes"
  type          = object({
    # no protocol
    base_domain = string

    bucket      = string
    password    = string
    port        = number
    ssl         = bool
    username    = string
  })
  default      = {
    base_domain = null
    bucket      = null
    password    = null
    port        = null
    ssl         = null
    username    = null
  }
}

variable "file_internal" {
  description        = "Database internal settings"
  type               = object({
    chart            = object({
      operator       = object({
        name         = string
        version      = string
      })
      repository     = string
      tenant         = object({
        name         = string
        version      = string
      })
    })
    port             = number
    pv_access        = string
    service          = string
    version          = string
  })
  default            = {
    chart            = {
      operator       = {
        name         = "operator"
        version      = "6.0.3"
      }
      repository     = "https://operator.min.io"
      tenant         = {
        name         = "tenant"
        version      = "6.0.3"
      }
    }
    port             = 9000
    pv_access        = "ReadWriteMany"
    service          = "minio"
    version          = "6.0.3"
  }
}


# GRAPH

variable "graph_existing" {
  description    = "Graph settings, if using an existing neo4j graph DB outside of Kubernetes"
  type           = object({
    addr         = string
    port         = number
  })
  default        = {
    addr         = null
    port         = null
  }
}

variable "graph_internal" {
  description        = "Neo4j internal settings"
  type               = object({
    chart        = object({
      name       = string
      url        = string
      version    = string
    })
    service          = string
  })
  default            = {
    chart            = {
      name           = "neo4j"
      url            = "https://helm.neo4j.com/neo4j"
      version        = "5.24.1"
    }
    service          = "neo4j"
  }
}


# GROUNDX

variable "groundx" {
  description     = "GroundX service information"
  type            = object({
    load_balancer = object({
      internal    = bool
      port        = number
    })
  })
  default         = {
    load_balancer = {
      internal    = false
      port        = 80
    }
  }
}

variable "groundx_internal" {
  description    = "GroundX internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    service      = string
    # all or search
    type         = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "groundx"
      tag        = "latest"
    }
    service      = "groundx"
    type         = "all"
    version      = "0.0.1"
  }
}


# LANGUAGES

variable "language_configs" {
  type                = map(
    object({
      models          = list(
        object({
          maxTokens   = number
          name        = string
          throughput  = number
          type        = string
          version     = string
          workers     = number
        })
      )
      search          = object({
        plugins       = object({
          enabled     = bool
          installList = list(string)
        })
      })
    })
  )
  default             = {
    en                = {
      models          = []
      search          = {
        plugins       = {
          enabled     = false
          installList = []
        }
      }
    }
  }
}


# LAYOUT

variable "layout" {
  type            = object({
    ocr           = object({
      credentials   = string
      project       = string
      type          = string
    })
  })
  default         = {
    ocr           = {
      credentials   = ""
      project       = ""
      type          = "tesseract"
    }
  }
  validation {
    condition     = var.layout.ocr.type != "google" || var.layout.ocr.project != ""
    error_message = "Project must be set if using Google OCR"
  }
}

variable "layout_process_batch_size" {
  type    = number
  default = 40
}

variable "layout_internal" {
  description    = "Layout internal settings"
  type           = object({
    api            = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
    })
    correct        = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
      queues       = string
    })
    inference      = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
      queues       = string
    })
    models         = object({
      device       = string
    })
    map            = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
      queues       = string
    })
    ocr            = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
      queues       = string
    })
    process        = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
      queues       = string
    })
    save           = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
      queues       = string
    })
    service        = string
    version        = string
  })
  default          = {
    api            = {
      image        = {
        pull       = "Always"
        repository = "python-api"
        tag        = "latest"
      }
    }
    correct        = {
      image        = {
        pull       = "Always"
        repository = "layout-process"
        tag        = "latest"
      }
      queues       = "correct_queue"
    }
    inference      = {
      image        = {
        pull       = "Always"
        repository = "layout-inference"
        tag        = "latest"
      }
      queues       = "layout_queue"
    }
    models         = {
      device       = "cuda"
    }
    map            = {
      image        = {
        pull       = "Always"
        repository = "layout-process"
        tag        = "latest"
      }
      queues       = "map_queue"
    }
    ocr            = {
      image        = {
        pull       = "Always"
        repository = "layout-process"
        tag        = "latest"
      }
      queues       = "ocr_queue"
    }
    process        = {
      image        = {
        pull       = "Always"
        repository = "layout-process"
        tag        = "latest"
      }
      queues       = "process_queue"
    }
    save           = {
      image        = {
        pull       = "Always"
        repository = "layout-process"
        tag        = "latest"
      }
      queues       = "save_queue"
    }
    service        = "layout"
    version        = "0.0.1"
  }
}


# LAYOUT WEBHOOK

variable "layout_webhook_internal" {
  description    = "Layout webhook internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    service      = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "layout-webhook"
      tag        = "latest"
    }
    service      = "layout-webhook"
    version      = "0.0.1"
  }
}


# METRICS

variable "metrics_internal" {
  description    = "Metrics internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    service      = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "metrics"
      tag        = "latest"
    }
    service      = "metrics"
    version      = "0.0.1"
  }
}


# PRE-PROCESS

variable "pre_process_internal" {
  description    = "Pre-Process internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    queue        = string
    service      = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "pre-process"
      tag        = "latest"
    }
    queue        = "file-pre-process"
    service      = "pre-process"
    version      = "0.0.1"
  }
}


# PROCESS

variable "process_internal" {
  description    = "Process internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    queue        = string
    service      = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "process"
      tag        = "latest"
    }
    queue        = "file-process"
    service      = "process"
    version      = "0.0.1"
  }
}


# QUEUE

variable "queue_internal" {
  description    = "Queue internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    queue        = string
    service      = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "queue"
      tag        = "latest"
    }
    queue        = "file-update"
    service      = "queue"
    version      = "0.0.1"
  }
}


# RANKER

variable "ranker_internal" {
  description      = "Ranker internal settings"
  type             = object({
    api            = object({
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
    })
    inference      = object({
      device       = string
      image        = object({
        pull       = string
        repository = string
        tag        = string
      })
      pv           = object({
        access     = string
        capacity   = string
        mount      = string
      })
      queues       = string
    })
    service        = string
    version        = string
  })
  default          = {
    api            = {
      image        = {
        pull       = "Always"
        repository = "python-api"
        tag        = "latest"
      }
    }
    inference      = {
      device       = "cuda"
      image        = {
        pull       = "Always"
        repository = "ranker-inference"
        tag        = "latest"
      }
      pv           = {
        access     = "ReadWriteMany"
        capacity   = "10Gi"
        mount      = "/mnt/ranker-model"
      }
      queues       = "inference_queue"
    }
    service        = "ranker"
    version        = "0.0.1"
  }
}


# SEARCH

variable "search" {
  description     = "Search service information"
  type            = object({
    index         = string
    password      = string
    root_password = string
    user          = string
  })
  default         = {
    index         = "prod-1"
    password      = "R0otb_*t!kazs"
    root_password = "R0otb_*t!kazs"
    user          = "eyelevel"
  }
}

variable "search_existing" {
  description     = "Search settings, if using an existing OpenSearch instance outside of Kubernetes"
  type            = object({
    # no protocol, no port
    base_domain   = string

    # includes protocol and port
    base_url      = string

    port          = number
  })
  default         = {
    base_domain   = null
    base_url      = null
    port          = null
  }
}

variable "search_internal" {
  description    = "Search internal settings"
  type           = object({
    chart        = object({
      name       = string
      url        = string
      version    = string
    })
    image        = object({
      name       = string
      repository = string
      tag        = string
    })
    port         = number
    service      = string
    version      = string
  })
  default        = {
    chart        = {
      name       = "opensearch"
      url        = "https://opensearch-project.github.io/helm-charts"
      version    = "2.23.1"
    }
    image        = {
      name       = "eyelevel/opensearch"
      repository = "public.ecr.aws/c9r4x6y5"
      tag        = "latest"
    }
    port         = 9200
    service      = "opensearch"
    version      = "2.16.0"
  }
}


# STREAM

variable "stream_base_url" {
  description = "Kafka base URL, if using an existing Kafka instance outside of Kubernetes"
  nullable    = true
  type        = string
  default     = null
}

variable "stream_existing" {
  description = "Stream settings, if using an existing Kafka instance outside of Kubernetes"
  type            = object({
    # no protocol, no port
    base_domain   = string
    port          = number
  })
  default         = {
    base_domain   = null
    port          = null
  }
}

variable "stream_internal" {
  description    = "Stream internal settings"
  type           = object({
    chart        = object({
      name       = string
      url        = string
      version    = string
    })
    meta_version = string
    port         = number
    service      = string
    version      = string
  })
  default        = {
    chart        = {
      name       = ""
      url        = "oci://quay.io/strimzi-helm/strimzi-kafka-operator"
      version    = "0.47.0"
    }
    meta_version = "4.0-IV3"
    port         = 9092
    service      = "kafka"
    version      = "4.0.0"
  }
}

# SUMMARY

variable "summary_existing" {
  description    = "Summary settings, if using OpenAI vs private hosted model"
  nullable       = true
  type           = object({
    api_key      = string
    base_url     = string
    service_type = string
  })
  default        = {
    api_key      = null
    base_url     = null
    service_type = null
  }
}

variable "summary_internal" {
  description       = "Summary internal settings"
  type              = object({
    api             = object({
      image         = object({
        pull        = string
        repository  = string
        tag         = string
      })
    })
    inference       = object({
      device        = string
      deviceUtilize = number
      image         = object({
        pull        = string
        repository  = string
        tag         = string
      })
      pv            = object({
        access      = string
        capacity    = string
        mount       = string
      })
      queues        = string
    })
    service         = string
    version         = string
  })
  default           = {
    api             = {
      image         = {
        pull        = "Always"
        repository  = "python-api"
        tag         = "latest"
      }
    }
    inference       = {
      device        = "cuda"
      deviceUtilize = 0.33
      image         = {
        pull        = "Always"
        repository  = "summary-inference"
        tag         = "latest"
      }
      pv            = {
        access      = "ReadWriteMany"
        capacity    = "20Gi"
        mount       = "/mnt/summary-model"
      }
      queues        = "summary_inference_queue"
    }
    service         = "summary"
    version         = "0.0.1"
  }
}


# SUMMARY CLIENT

variable "summary_client_internal" {
  description    = "Summary client internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    queue        = string
    service      = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "summary-client"
      tag        = "latest"
    }
    queue        = "file-summary"
    service      = "summary-client"
    version      = "0.0.1"
  }
}


# UPLOAD

variable "upload_internal" {
  description    = "Upload internal settings"
  type           = object({
    image        = object({
      pull       = string
      repository = string
      tag        = string
    })
    queue        = string
    service      = string
    version      = string
  })
  default        = {
    image        = {
      pull       = "Always"
      repository = "upload"
      tag        = "latest"
    }
    queue        = "file-upload"
    service      = "upload"
    version      = "0.0.1"
  }
}

# CLI

variable "DEV" {
  type    = number
  default = 0
  description = "Set to 1 for development containers."
}