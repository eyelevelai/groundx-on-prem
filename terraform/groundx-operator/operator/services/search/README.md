# Search Directory: User Guide

The search directory manages the OpenSearch configuration for the EyeLevel application. This guide explains the workflow and the parameters you can customize.

## Workflow

1. **Determine OpenSearch Deployment**
   - The system checks if an existing OpenSearch instance is specified.
   - If not, it prepares to create a new OpenSearch deployment.

2. **Configure OpenSearch Settings**
   - Combines settings from existing OpenSearch (if any) and internal defaults.

3. **Deploy OpenSearch Operator (if needed)**
   - Uses Helm to deploy the OpenSearch Operator with specified configurations.

## User-Configurable Parameters

### Existing OpenSearch Configuration
Use these parameters if you have an existing OpenSearch instance:

```hcl
variable "search_existing" {
  type = object({
    base_domain = string
    base_url    = string
    port        = number
  })
}
```

- `base_domain`: Base domain of your existing OpenSearch instance (no protocol, no port).
- `base_url`: Full URL of your existing OpenSearch instance (includes protocol and port).
- `port`: Port number of your existing OpenSearch instance.

**Note**: Leave these null to deploy a new OpenSearch instance.

### Search Service Information
Customize these for OpenSearch credentials and index:

```hcl
variable "search" {
  type = object({
    index         = string
    password      = string
    root_password = string
    user          = string
  })
}
```

- `index`: Name of the index to use.
- `password`: Password for OpenSearch access.
- `root_password`: Root password for OpenSearch.
- `user`: Username for OpenSearch access.

### Internal OpenSearch Settings
Customize these for a new OpenSearch deployment:

```hcl
variable "search_internal" {
  type = object({
    chart    = object({...})
    image    = object({...})
    node     = string
    port     = number
    service  = string
    version  = string
  })
}
```

Key parameters:
- `node`: Specify the node type for deployment (e.g., "cpu").
- `port`: Set the OpenSearch port (default is usually 9200).
- `service`: Name for the OpenSearch service.
- `version`: Specify the OpenSearch version.

### Resource Allocation
Control the resources allocated to OpenSearch:

```hcl
variable "search_resources" {
  type = object({
    pv_size   = string
    replicas  = number
    resources = object({
      requests = object({
        cpu    = string
        memory = string
      })
    })
  })
}
```

- `pv_size`: Size of the persistent volume for OpenSearch data.
- `replicas`: Number of OpenSearch replicas for high availability.
- `resources.requests`: CPU and memory requests for OpenSearch nodes.

## Usage Examples

### Using an Existing OpenSearch Instance

```hcl
module "search" {
  source = "./search"
  
  search_existing = {
    base_domain = "opensearch.example.com"
    base_url    = "https://opensearch.example.com:9200"
    port        = 9200
  }
}
```

### Deploying a New OpenSearch Instance

```hcl
module "search" {
  source = "./search"
  
  search = {
    index         = "my-index"
    password      = "securepassword"
    root_password = "securerootpassword"
    user          = "opensearch-user"
  }
  
  search_internal = {
    node     = "high-memory"
    port     = 9200
    service  = "my-opensearch"
    version  = "2.16.0"
  }
  
  search_resources = {
    pv_size  = "50Gi"
    replicas = 3
    resources = {
      requests = {
        cpu    = "2"
        memory = "4Gi"
      }
    }
  }
}
```