# Stream Directory: User Guide

The stream directory manages the Apache Kafka configuration for the EyeLevel application using the Strimzi operator. This guide explains the workflow and the parameters you can customize.

## Workflow

1. **Determine Kafka Deployment**
   - The system checks if an existing Kafka instance is specified.
   - If not, it prepares to create a new Kafka deployment.

2. **Configure Kafka Settings**
   - Combines settings from existing Kafka (if any) and internal defaults.

3. **Deploy Strimzi Operator (if needed)**
   - Uses Helm to deploy the Strimzi Operator with specified configurations.

4. **Deploy Kafka Cluster (if needed)**
   - Uses Helm to deploy the Kafka Cluster with specified configurations.

## User-Configurable Parameters

### Existing Kafka Configuration
Use these parameters if you have an existing Kafka instance:

```hcl
variable "stream_existing" {
  type = object({
    base_domain = string
    base_url    = string
    port        = number
  })
}
```

- `base_domain`: Base domain of your existing Kafka instance (no protocol, no port).
- `base_url`: Full URL of your existing Kafka instance (includes protocol and port).
- `port`: Port number of your existing Kafka instance.

**Note**: Leave these null to deploy a new Kafka instance.

### Internal Kafka Settings
Customize these for a new Kafka deployment:

```hcl
variable "stream_internal" {
  type = object({
    chart    = object({
      url     = string
      version = string
    })
    node     = string
    port     = number
    service  = string
    version  = string
  })
}
```

Key parameters:
- `node`: Specify the node type for deployment (e.g., "cpu").
- `port`: Set the Kafka port (default is usually 9092).
- `service`: Name for the Kafka service.
- `version`: Specify the Kafka version.

### Resource Allocation
Control the resources allocated to Kafka:

```hcl
variable "stream_resources" {
  type = object({
    operator        = object({...})
    partitions      = number
    resources       = object({...})
    retention_bytes = number
    segment_bytes   = number
    service         = object({...})
    zookeeper       = object({...})
  })
}
```

Key parameters:
- `partitions`: Number of partitions for Kafka topics.
- `retention_bytes`: Maximum size of the log before deleting old segments.
- `segment_bytes`: Maximum size of a single log segment.
- `service.replicas`: Number of Kafka broker replicas.
- `service.storage`: Size of storage for each Kafka broker.
- `nodepool.replicas`: Number of nodes in the pool.
- `nodepool.storage`: Size of storage for each node.

## Usage Examples

### Using an Existing Kafka Instance

```hcl
module "stream" {
  source = "./stream"
  
  stream_existing = {
    base_domain = "kafka.example.com"
    base_url    = "kafka://kafka.example.com:9092"
    port        = 9092
  }
}
```

### Deploying a New Kafka Cluster

```hcl
module "stream" {
  source = "./stream"
  
  stream_internal = {
    node    = "high-cpu"
    port    = 9092
    service = "my-kafka"
    version = "3.4.0"
  }
  
  stream_resources = {
    partitions      = 6
    retention_bytes = 2147483648  # 2GB
    segment_bytes   = 536870912   # 512MB
    service = {
      replicas = 5
      storage  = "50Gi"
    }
    zookeeper = {
      replicas = 3
      storage  = "20Gi"
    }
    resources = {
      limits = {
        cpu    = "2"
        memory = "4Gi"
      }
      requests = {
        cpu    = "1"
        memory = "2Gi"
      }
    }
  }
}
```