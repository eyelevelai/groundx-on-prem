# File Directory: User Guide

The file directory manages the MinIO object storage configuration for the EyeLevel application. This guide explains the workflow and the parameters you can customize.

## Workflow

1. **Determine MinIO Deployment**
   - The system checks if an existing MinIO instance is specified.
   - If not, it prepares to create a new MinIO deployment.

2. **Configure MinIO Settings**
   - Combines settings from existing MinIO (if any) and internal defaults.

3. **Deploy MinIO Operator (if needed)**
   - Adds the MinIO Helm repository.
   - Deploys the MinIO Operator using Helm.

4. **Deploy MinIO Tenant (if needed)**
   - Uses Helm to deploy the MinIO Tenant with specified configurations.

## User-Configurable Parameters

### Existing MinIO Configuration
Use these parameters if you have an existing MinIO instance:

```hcl
variable "file_existing" {
  type = object({
    base_domain = string
    bucket      = string
    password    = string
    port        = number
    ssl         = bool
    username    = string
  })
}
```

- `base_domain`: Base domain of your existing MinIO instance (no protocol).
- `bucket`: Name of the bucket to use.
- `password`: Password for MinIO access.
- `port`: Port number of your existing MinIO instance.
- `ssl`: Whether SSL is enabled (true/false).
- `username`: Username for MinIO access.

**Note**: Leave these null to deploy a new MinIO instance.

### File Service Information
Customize these for MinIO credentials and bucket:

```hcl
variable "file" {
  type = object({
    password      = string
    upload_bucket = string
    username      = string
  })
}
```

- `password`: Password for MinIO access.
- `upload_bucket`: Name of the bucket for uploads.
- `username`: Username for MinIO access.

### Internal MinIO Settings
Customize these for a new MinIO deployment:

```hcl
variable "file_internal" {
  type = object({
    chart_base       = string
    chart_repository = string
    node             = string
    operator         = object({...})
    port             = number
    pv_access        = string
    service          = string
    tenant           = object({...})
    version          = string
  })
}
```

Key parameters:
- `node`: Specify the node type for deployment (e.g., "cpu").
- `port`: Set the MinIO port (default is usually 9000).
- `pv_access`: Persistent volume access mode.
- `service`: Name for the MinIO service.
- `version`: Specify the MinIO version.

### Resource Allocation
Control the resources allocated to MinIO:

```hcl
variable "file_resources" {
  type = object({
    operator            = object({...})
    pool_size           = string
    pool_servers        = number
    pool_server_volumes = number
    pv_path             = string
    resources           = object({...})
    ssl                 = bool
  })
}
```

- `pool_size`: Size of the storage pool.
- `pool_servers`: Number of MinIO servers.
- `pool_server_volumes`: Number of volumes per server.
- `resources`: CPU and memory limits and requests for MinIO.
- `ssl`: Enable or disable SSL.

## Usage Examples

### Using an Existing MinIO Instance

```hcl
module "file_storage" {
  source = "./file"
  
  file_existing = {
    base_domain = "minio.example.com"
    bucket      = "my-bucket"
    password    = "securepassword"
    port        = 9000
    ssl         = true
    username    = "minio-user"
  }
}
```

### Deploying a New MinIO Instance

```hcl
module "file_storage" {
  source = "./file"
  
  file = {
    password      = "securepassword"
    upload_bucket = "uploads"
    username      = "minio-user"
  }
  
  file_internal = {
    node    = "high-storage"
    port    = 9000
    service = "minio-storage"
    version = "6.0.3"
  }
  
  file_resources = {
    pool_size           = "500Gi"
    pool_servers        = 4
    pool_server_volumes = 1
    resources = {
      limits = {
        cpu    = "1"
        memory = "2Gi"
      }
      requests = {
        cpu    = "500m"
        memory = "1Gi"
      }
    }
    ssl = true
  }
}
```