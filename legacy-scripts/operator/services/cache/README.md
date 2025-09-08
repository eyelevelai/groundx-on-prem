# Cache Directory: User Guide
The cache directory manages the Redis cache configuration for the EyeLevel application. This guide explains the workflow and the parameters you can customize.

## Workflow

1. **Determine Cache Creation**
   - The system checks if an existing cache is specified.
   - If not, it prepares to create a new Redis cache.

2. **Configure Cache Settings**
   - Combines settings from existing cache (if any) and internal defaults.

3. **Deploy Redis (if needed)**
   - Uses Helm to deploy Redis with specified configurations.

4. **Set Up Security Context**
   - Adapts to OpenShift environments if necessary.

## User-Configurable Parameters

### Existing Cache Configuration
Use these parameters if you have an existing Redis cache:

```hcl
variable "cache_existing" {
  type = object({
    addr        = string
    is_instance = bool
    port        = number
  })
}
```

- `addr`: Address of your existing Redis cache.
- `is_instance`: Set to `true` if it's a Redis instance, `false` otherwise.
- `port`: Port number of your existing Redis cache.

**Note**: Leave these null to deploy a new Redis cache.

### Internal Cache Settings
Customize these for a new Redis deployment:

```hcl
variable "cache_internal" {
  type = object({
    image            = object({...})
    is_instance      = bool
    mount_path       = string
    node             = string
    operator_version = string
    port             = number
    service          = string
    version          = string
  })
}
```

Key parameters:
- `image`: Customize the Redis image details.
- `mount_path`: Set the persistence path for Redis data.
- `node`: Specify the node type for deployment (e.g., "cpu").
- `port`: Set the Redis port (default is usually 6379).
- `service`: Name for the Redis service.
- `version`: Specify the Redis version.

### Resource Allocation
Control the resources allocated to Redis:

```hcl
variable "cache_resources" {
  type = object({
    replicas  = number
    resources = object({
      limits   = object({
        cpu    = string
        memory = string
      })
      requests = object({
        cpu    = string
        memory = string
      })
    })
  })
}
```

- `replicas`: Number of Redis replicas for high availability.
- `resources.limits`: Maximum CPU and memory allocation.
- `resources.requests`: Minimum CPU and memory allocation.

## Usage Examples

### Using an Existing Cache

```hcl
module "cache" {
  source = "./cache"
  
  cache_existing = {
    addr        = "redis.example.com"
    is_instance = true
    port        = 6379
  }
}
```

### Deploying a New Cache with Custom Settings

```hcl
module "cache" {
  source = "./cache"
  
  cache_internal = {
    image = {
      repository = "custom-redis"
      tag        = "6.2"
    }
    mount_path = "/data/redis"
    node       = "high-memory"
    port       = 6380
    service    = "my-redis"
    version    = "6.2"
  }
  
  cache_resources = {
    replicas = 3
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