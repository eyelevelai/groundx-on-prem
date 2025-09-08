# Database (DB) Directory: User Guide

The db directory manages the database configuration for the EyeLevel application, specifically using Percona XtraDB Cluster (PXC) for MySQL. This guide explains the workflow and the parameters you can customize.

## Workflow

1. **Determine Database Deployment**
   - The system checks if an existing database is specified.
   - If not, it prepares to create a new Percona XtraDB Cluster.

2. **Configure Database Settings**
   - Combines settings from existing database (if any) and internal defaults.

3. **Deploy Percona Operator (if needed)**
   - Adds the Percona Helm repository.
   - Deploys the Percona Operator using Helm.

4. **Deploy Percona XtraDB Cluster (if needed)**
   - Uses Helm to deploy the Percona XtraDB Cluster with specified configurations.

## User-Configurable Parameters

### Existing Database Configuration
Use these parameters if you have an existing database:

```hcl
variable "db_existing" {
  type = object({
    port = number
    ro   = string
    rw   = string
  })
}
```

- `port`: Port number of your existing database.
- `ro`: Read-only endpoint of your existing database.
- `rw`: Read-write endpoint of your existing database.

**Note**: Leave these null to deploy a new Percona XtraDB Cluster.

### Database Service Information
Customize these for database credentials:

```hcl
variable "db" {
  type = object({
    db_name          = string
    db_password      = string
    db_root_password = string
    db_username      = string
  })
}
```

- `db_name`: Name of the database to create.
- `db_password`: Password for the database user.
- `db_root_password`: Root password for the database.
- `db_username`: Username for the database user.

### Internal Database Settings
Customize these for a new Percona XtraDB Cluster deployment:

```hcl
variable "db_internal" {
  type = object({
    backup                = bool
    chart                 = object({...})
    disable_unsafe_checks = bool
    ip_type               = string
    logcollector_enable   = bool
    node                  = string
    pmm_enable            = bool
    port                  = number
    service               = string
    version               = string
  })
}
```

Key parameters:
- `backup`: Enable or disable backups.
- `disable_unsafe_checks`: Allow unsafe configurations (use with caution).
- `logcollector_enable`: Enable or disable log collection.
- `node`: Specify the node type for deployment (e.g., "cpu").
- `pmm_enable`: Enable or disable Percona Monitoring and Management.
- `port`: Set the database port (default is usually 3306).
- `service`: Name for the database service.
- `version`: Specify the Percona XtraDB Cluster version.

### Resource Allocation
Control the resources allocated to the database:

```hcl
variable "db_resources" {
  type = object({
    proxy    = object({...})
    pv_size  = string
    replicas = number
    resources = object({
      limits   = object({...})
      requests = object({...})
    })
  })
}
```

- `proxy`: Configure HAProxy settings (replicas and resources).
- `pv_size`: Size of the persistent volume for each database node.
- `replicas`: Number of database replicas for high availability.
- `resources`: CPU and memory limits and requests for database nodes.

## Usage Examples

### Using an Existing Database

```hcl
module "database" {
  source = "./db"
  
  db_existing = {
    port = 3306
    ro   = "read-endpoint.example.com"
    rw   = "write-endpoint.example.com"
  }
}
```

### Deploying a New Percona XtraDB Cluster

```hcl
module "database" {
  source = "./db"
  
  db = {
    db_name          = "myapp"
    db_password      = "securepassword"
    db_root_password = "securerootpassword"
    db_username      = "myappuser"
  }
  
  db_internal = {
    backup                = true
    disable_unsafe_checks = false
    logcollector_enable   = true
    node                  = "high-memory"
    pmm_enable            = true
    port                  = 3306
    service               = "myapp-db"
    version               = "8.0"
  }
  
  db_resources = {
    pv_size  = "50Gi"
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
``