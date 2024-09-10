# GLOBALS

variable "cluster_role" {
  description = "Your cluster role (developer, admin)"
  type        = string
  default     = "developer"
}

variable "cluster_type" {
  description = "Type of Kubernetes cluster"
  type        = string
  default     = "openshift"
}

variable "create_all" {
  description = "Create all services"
  type        = bool
  default     = true
}

variable "create_groundx" {
  description = "Create GroundX service"
  type        = bool
  default     = true
}

variable "create_kafka" {
  description = "Create Kafka service"
  type        = bool
  default     = true
}

variable "create_minio" {
  description = "Create MinIO service"
  type        = bool
  default     = true
}

variable "create_mysql" {
  description = "Create MySQL service"
  type        = bool
  default     = true
}

variable "create_opensearch" {
  description = "Create Open Search service"
  type        = bool
  default     = true
}

variable "create_ranker" {
  description = "Create GroundX Search ranker service, sets create_redis to true when true"
  type        = bool
  default     = true
}

variable "create_redis" {
  description = "Create Redis service"
  type        = bool
  default     = true
}

variable "kube_config_path" {
  description = "Path to Kubernetes cluster config file"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "Namespace for cluster"
  type        = string
  default     = "eyelevel"
}

variable "pv_class" {
  description = "Storage class for the PersistentVolume and PersistentVolumeClaim"
  type        = string
  default     = "local-storage"
}


# CACHE

variable "cache_bundle_version" {
  description = "Redis Enterprise bundle version"
  type        = string
  default     = "v7.4.6-2"
}

variable "cache_cpu_limits" {
  description = "CPU allocated to requests"
  type        = string
  default     = "2"
}

variable "cache_cpu_requests" {
  description = "CPU allocated to requests"
  type        = string
  default     = "2"
}

variable "cache_memory_limits" {
  description = "Memory allocated to limits"
  type        = string
  default     = "16Gi"
}

variable "cache_memory_requests" {
  description = "Memory allocated to requests"
  type        = string
  default     = "16Gi"
}

variable "cache_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "cache_replicas" {
  description = "Number of initial database replicas"
  type        = number
  default     = 3
}

variable "cache_service" {
  description = "Name for service"
  type        = string
  default     = "redis"
}

# LOCAL CACHE

variable "cache_image_pull" {
  description = "Pull policy for container image"
  type        = string
  default     = "Always"
}

variable "cache_image_tag" {
  description = "Tag for container image"
  type        = string
  default     = "latest"
}

variable "cache_image_url" {
  description = "Address for container image"
  type        = string
  default     = "public.ecr.aws/c9r4x6y5/eyelevel/redis"
}

variable "cache_ip_type" {
  description = "Type of IP address"
  type        = string
  default     = "ClusterIP"
}


variable "cache_is_instance" {
  description = "Defines whether redis is a cluster or instance"
  type        = bool
  default     = true
}

variable "cache_mount_path" {
  description = "Container path where redis data will mount"
  type        = string
  default     = "/mnt/redis"
}

variable "cache_port" {
  description = "Local port for access"
  type        = number
  default     = 6379
}

variable "cache_pv_access" {
  description = "Access modes for the PersistentVolume and PersistentVolumeClaim"
  type        = string
  default     = "ReadWriteMany"
}

variable "cache_pv_path" {
  description = "Local path for the PersistentVolume"
  type        = string
}

variable "cache_pv_size" {
  description = "Size of the PersistentVolume and PersistentVolumeClaim"
  type        = string
  default     = "1Gi"
}

variable "cache_version" {
  description = "Redis version"
  type        = string
  default     = "6.1"
}


# DASHBOARD

variable "dashboard_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "dashboard_service" {
  description = "Name for service"
  type        = string
  default     = "dashboard"
}


# DATABASE

variable "db_backup_enable" {
  description = "Enable database backups"
  type        = bool
  default     = true
}

variable "db_disable_check_unsafe" {
  description = "Disable unsafe checks"
  type        = bool
  default     = false
}

variable "db_ip_type" {
  description = "Type of IP address"
  type        = string
  default     = "ClusterIP"
}

variable "db_ha_proxy_cpu_limits" {
  description = "CPU allocated to requests"
  type        = string
  default     = "600m"
}

variable "db_ha_proxy_cpu_requests" {
  description = "CPU allocated to requests"
  type        = string
  default     = "600m"
}

variable "db_ha_proxy_memory_limits" {
  description = "Memory allocated to limits"
  type        = string
  default     = "1Gi"
}

variable "db_ha_proxy_memory_requests" {
  description = "Memory allocated to requests"
  type        = string
  default     = "1Gi"
}

variable "db_ha_proxy_replicas" {
  description = "Number of initial high availability proxy replicas"
  type        = number
  default     = 3
}

variable "db_logcollector_enable" {
  description = "Enable log collector pods"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "eyelevel"
}

variable "db_node" {
  description = "Node where the PersistentVolume will be available"
  type        = string
  default     = "crc"
}

variable "db_password" {
  description = "MySQL user password"
  type        = string
}

variable "db_pmm_enable" {
  description = "Enable monitoring and management"
  type        = bool
  default     = false
}

variable "db_pv_size" {
  description = "Size of the PersistentVolume and PersistentVolumeClaim"
  type        = string
  default     = "20Gi"
}

variable "db_pxc_cpu_limits" {
  description = "CPU allocated to requests"
  type        = string
  default     = "600m"
}

variable "db_pxc_cpu_requests" {
  description = "CPU allocated to requests"
  type        = string
  default     = "600m"
}

variable "db_pxc_memory_limits" {
  description = "Memory allocated to limits"
  type        = string
  default     = "1Gi"
}

variable "db_pxc_memory_requests" {
  description = "Memory allocated to requests"
  type        = string
  default     = "1Gi"
}

variable "db_replicas" {
  description = "Number of initial database replicas"
  type        = number
  default     = 3
}

variable "db_root_password" {
  description = "MySQL root password"
  type        = string
  default     = "rootpassword"
}

variable "db_service" {
  description = "Name for service"
  type        = string
  default     = "mysql"
}

variable "db_service_version" {
  description = "Version for service"
  type        = string
  default     = "8.0"
}

variable "db_username" {
  description = "MySQL user username"
  type        = string
  default     = "eyelevel"
}


# FILE

variable "file_access_key" {
  description = "MinIO access key"
  type        = string
  default     = "minio"
}

variable "file_access_secret" {
  description = "MinIO access secret"
  type        = string
  default     = "minio123"
}

variable "file_chart_operator" {
  description = "Helm chart for MinIO operator"
  type        = string
  default     = "minio-operator/operator"
}

variable "file_chart_tenant" {
  description = "Helm chart for MinIO tenant"
  type        = string
  default     = "minio-operator/tenant"
}

variable "file_chart_repository" {
  description = "Helm chart repository for MinIO operator"
  type        = string
  default     = "https://operator.min.io"
}

variable "file_chart_repository_name" {
  description = "Helm chart repository name for MinIO operator"
  type        = string
  default     = "minio-operator"
}

variable "file_chart_operator_version" {
  description = "Helm chart version for MinIO operator"
  type        = string
  default     = "6.0.3"
}

variable "file_chart_tenant_version" {
  description = "Helm chart version for MinIO tenant"
  type        = string
  default     = "6.0.3"
}

variable "file_cpu_limits" {
  description = "CPU allocated to requests"
  type        = string
  default     = "4"
}

variable "file_cpu_requests" {
  description = "CPU allocated to requests"
  type        = string
  default     = "2"
}

variable "file_memory_limits" {
  description = "Memory allocated to limits"
  type        = string
  default     = "8Gi"
}

variable "file_memory_requests" {
  description = "Memory allocated to requests"
  type        = string
  default     = "4Gi"
}

variable "file_node" {
  description = "Node where the PersistentVolume will be available"
  type        = string
  default     = "crc"
}

variable "file_pool_server" {
  description = "Servers allocated to MinIO deployment"
  type        = number
  default     = 4
}

variable "file_pool_server_volumes" {
  description = "Volumes allocated per server"
  type        = number
  default     = 4
}

variable "file_pool_size" {
  description = "Disk space allocated to MinIO deployment"
  type        = string
  default     = "1Ti"
}

variable "file_pv_access" {
  description = "Access modes for the PersistentVolume and PersistentVolumeClaim"
  type        = string
  default     = "ReadWriteMany"
}

variable "file_pv_path" {
  description = "Local path for the PersistentVolume"
  type        = string
}

variable "file_replicas_operator" {
  description = "Number of initial operator replicas"
  type        = number
  default     = 2
}

variable "file_replicas_tenant" {
  description = "Number of initial tenant replicas"
  type        = number
  default     = 2
}

variable "file_service" {
  description = "Name for service"
  type        = string
  default     = "minio"
}

variable "file_version" {
  description = "MinIO version"
  type        = string
  default     = "6.0.3"
}


# GROUNDX

variable "groundx_image_pull" {
  description = "Pull policy for container image"
  type        = string
  default     = "Always"
}

variable "groundx_image_tag" {
  description = "Tag for container image"
  type        = string
  default     = "latest"
}

variable "groundx_image_url" {
  description = "Address for container image"
  type        = string
  default     = "public.ecr.aws/c9r4x6y5/eyelevel/groundx"
}

variable "groundx_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "groundx_service" {
  description = "Name for service"
  type        = string
  default     = "groundx"
}

variable "groundx_service_key" {
  description = "API key for GroundX service"
  type        = string
  default     = "0c2f6b3e-0746-4280-8ef2-2c65f596b40b"
}

variable "groundx_username" {
  description = "Username for GroundX service"
  type        = string
  default     = "0c2f6b3e-0746-4280-8ef2-2c65f596b40b"
}

variable "groundx_valid_service_keys" {
  description = "List of valid service API keys for internal service requests"
  type        = list(string)
  default     = [
    "0c2f6b3e-0746-4280-8ef2-2c65f596b40b"
  ]
}

variable "groundx_version" {
  description = "GroundX version"
  type        = string
  default     = "0.0.1"
}


# LAYOUT

variable "layout_api_node" {
  description = "Node where the API (CPU) service will be available"
  type        = string
  default     = "crc"
}

variable "layout_inference_node" {
  description = "Node where the inference (GPU) service will be available"
  type        = string
  default     = "crc"
}

variable "layout_service" {
  description = "Name for service"
  type        = string
  default     = "layout"
}


# LAYOUT WEBHOOK

variable "layout_webhook_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "layout_webhook_service" {
  description = "Name for service"
  type        = string
  default     = "layout-webhook"
}


# QUEUE

variable "queue_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "queue_service" {
  description = "Name for service"
  type        = string
  default     = "queue"
}


# PREPROCESS

variable "preprocess_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "preprocess_service" {
  description = "Name for service"
  type        = string
  default     = "preprocess"
}


# PROCESS

variable "process_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "process_service" {
  description = "Name for service"
  type        = string
  default     = "process"
}


# RANKER

variable "ranker_api_image_pull" {
  description = "Pull policy for container image"
  type        = string
  default     = "Always"
}

variable "ranker_api_image_tag" {
  description = "Tag for container image"
  type        = string
  default     = "latest"
}

variable "ranker_api_image_url" {
  description = "Address for container image"
  type        = string
  default     = "public.ecr.aws/c9r4x6y5/eyelevel/ranker-api"
}

variable "ranker_api_node" {
  description = "Node where the API (CPU) service will be available"
  type        = string
  default     = "crc"
}

variable "ranker_inference_device" {
  description = "Device type for inference (cpu or cuda)"
  type        = string
  default     = "cuda"
}

variable "ranker_inference_image_pull" {
  description = "Pull policy for container image"
  type        = string
  default     = "Always"
}

variable "ranker_inference_image_tag" {
  description = "Tag for container image"
  type        = string
  default     = "latest"
}

variable "ranker_inference_image_url" {
  description = "Address for container image"
  type        = string
  default     = "public.ecr.aws/c9r4x6y5/eyelevel/ranker-inference"
}

variable "ranker_inference_max_batch" {
  description = "Max number of prompts to process in a single inference"
  type        = number
  default     = 10
}

variable "ranker_inference_max_prompt" {
  description = "Max number of prompt tokens to process in a single inference"
  type        = number
  default     = 2048
}

variable "ranker_inference_model" {
  description = "Base ranker model"
  type        = string
  default     = "facebook/opt-350m"
}

variable "ranker_inference_node" {
  description = "Node where the inference (GPU) service will be available"
  type        = string
  default     = "crc"
}

variable "ranker_service" {
  description = "Name for service"
  type        = string
  default     = "ranker"
}

variable "ranker_version" {
  description = "Search Ranker version"
  type        = string
  default     = "0.0.1"
}


# SEARCH

variable "search_chart_name" {
  description = "Helm chart for Open Search operator"
  type        = string
  default     = "opensearch"
}

variable "search_chart_url" {
  description = "Helm chart repository URL"
  type        = string
  default     = "https://opensearch-project.github.io/helm-charts"
}

variable "search_chart_version" {
  description = "Helm chart version for Open Search operator"
  type        = string
  default     = "2.23.1"
}

variable "search_cpu_requests" {
  description = "CPU allocated to requests"
  type        = string
  default     = "1"
}

variable "search_image_repository" {
  description = "Pull policy for container image"
  type        = string
  default     = "eyelevel/opensearch"
}

variable "search_image_tag" {
  description = "Tag for container image"
  type        = string
  default     = "latest"
}

variable "search_image_url" {
  description = "Address for container image"
  type        = string
  default     = "public.ecr.aws/c9r4x6y5"
}

variable "search_index" {
  description = "Search index name where new records will be created"
  type        = string
  default     = "prod-1"
}

variable "search_memory_requests" {
  description = "Memory allocated to requests"
  type        = string
  default     = "512Mi"
}

variable "search_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "search_password" {
  description = "Search user password"
  type        = string
  default     = "password"
}

variable "search_pv_size" {
  description = "Memory allocated to requests"
  type        = string
  default     = "1Gi"
}

variable "search_replicas" {
  description = "Number of initial search replicas"
  type        = number
  default     = 3
}

variable "search_root_password" {
  description = "Open Search root password"
  type        = string
  default     = "R0otb_*t!kazs"
}

variable "search_service" {
  description = "Name for service"
  type        = string
  default     = "opensearch"
}

variable "search_user" {
  description = "Search user username"
  type        = string
  default     = "eyelevel"
}

variable "search_version" {
  description = "Open Search version"
  type        = string
  default     = "2.16.0"
}


# STREAM

variable "stream_chart" {
  description = "Helm chart for Kafka operator"
  type        = string
  default     = "oci://quay.io/strimzi-helm/strimzi-kafka-operator"
}

variable "stream_chart_version" {
  description = "Helm chart version for Kafka operator"
  type        = string
  default     = "0.35.0"
}

variable "stream_cpu_limits" {
  description = "CPU allocated to limits"
  type        = string
  default     = "4"
}

variable "stream_cpu_requests" {
  description = "CPU allocated to requests"
  type        = string
  default     = "2"
}

variable "stream_memory_limits" {
  description = "Memory allocated to limits"
  type        = string
  default     = "8Gi"
}

variable "stream_memory_requests" {
  description = "Memory allocated to requests"
  type        = string
  default     = "4Gi"
}

variable "stream_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "stream_partitions" {
  description = "Number of initial topic partitions"
  type        = number
  default     = 3
}

variable "stream_port" {
  description = "Local port for access"
  type        = number
  default     = 9092
}

variable "stream_replicas_operator" {
  description = "Number of initial operator replicas"
  type        = number
  default     = 3
}

variable "stream_replicas_service" {
  description = "Number of initial service replicas"
  type        = number
  default     = 3
}

variable "stream_replicas_zookeeper" {
  description = "Number of initial zookeeper replicas"
  type        = number
  default     = 3
}

variable "stream_retention_bytes" {
  description = "Storage memory allocated to each topic retention"
  type        = number
  default     = 1073741824
}

variable "stream_segment_bytes" {
  description = "Storage memory allocated to each topic partition"
  type        = number
  default     = 1073741824
}

variable "stream_service" {
  description = "Name for service"
  type        = string
  default     = "kafka"
}

variable "stream_storage_service" {
  description = "Storage memory allocated to service"
  type        = string
  default     = "20Gi"
}

variable "stream_storage_zookeeper" {
  description = "Storage memory allocated to zookeeper"
  type        = string
  default     = "10Gi"
}

variable "stream_version" {
  description = "Kafka version"
  type        = string
  default     = "3.4.0"
}


# SUMMARY

variable "summary_api_node" {
  description = "Node where the API (CPU) service will be available"
  type        = string
  default     = "crc"
}

variable "summary_inference_node" {
  description = "Node where the inference (GPU) service will be available"
  type        = string
  default     = "crc"
}
variable "summary_service" {
  description = "Name for service"
  type        = string
  default     = "summary"
}


# UPLOAD

variable "upload_node" {
  description = "Node where the service will be available"
  type        = string
  default     = "crc"
}

variable "upload_service" {
  description = "Name for service"
  type        = string
  default     = "upload"
}

# load balancer

variable "loadbalancer-name" {
  default = "loadbalancer-groundx"
}

variable "loadbalancer_type" {
  default = "LoadBalancer"
}

variable "loadbalancer_port" {
  default = 80
}

variable "loadbalancer_target_port" {
  default = 8080
}
