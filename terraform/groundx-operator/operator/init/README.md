# Operator Init Directory Documentation

This directory describes the logic for when the `./operator.sh init` command is issued. The logic handles EyeLevel application's infrastructure as code (IaC) setup. It contains Terraform configurations responsible for initializing and configuring various aspects of the application within a Kubernetes cluster.

## Directory Structure

```
operator/init/
├── add/
│   ├── app.tf
│   ├── common.tf
│   ├── helm_release.tf
│   ├── locals.tf
│   └── variable.tf
├── config/
│   ├── common.tf
│   ├── config-files.tf
│   └── init-files.tf
│   ├── helm_release.tf
│   ├── locals.tf
│   └── variable.tf
└── locals.tf
```

## Key Components

### locals.tf (Root)

- **Purpose**: Defines the module path for the entire init directory.
- **Key Configuration**: 
  ```hcl
  locals {
    module_path = "${path.module}/../../../modules"
  }
  ```

### `Add` Subdirectory

The directory contains logic that handles the workflow for when the `operator.sh init add` command is released.

#### app.tf
* **Purpose**: Sets up core Kubernetes resources and SSL certificates.
* **Key Resources**:
	* Kubernetes namespace
	* Local storage class (conditional)
	* Self-signed CA certificate
	* Service certificate signed by the CA
	* Kubernetes secret for SSL certificates

#### common.tf
- **Purpose**: Configures the Kubernetes provider and defines local variables for various services.

#### c. helm_release.tf
- **Purpose**: Configures the Helm provider for deploying Helm charts.

#### d. locals.tf
- **Purpose**: Defines local variables specific to the add subdirectory.

#### e. variable.tf
- **Purpose**: Defines input variables used throughout the add subdirectory.

### `Config` Subdirectory

#### a. common.tf
- **Purpose**: Similar to the common.tf in the `add` subdirectory, it sets up the Kubernetes provider and defines local variables for various services.

#### config-files.tf
* **Purpose**: Generates configuration files and creates Kubernetes ConfigMaps for various services.
* **Key Components**:
	* Main application configuration (config.yaml)
	* Layout service configuration
	* Ranker service configuration
	* Summary service configuration
	* Supervisord configurations for Layout, Ranker, and Summary services

#### init-files.tf
* **Purpose**: Creates a database initialization script and stores it in a Kubernetes ConfigMap.
* **Key Resource**: 
	* Kubernetes ConfigMap containing the init-db.sql script.

## Workflow and Dependencies

1. The root `locals.tf` file sets the base module path used throughout the init directory.
2. The `add` subdirectory sets up the foundational Kubernetes resources, including the namespace, SSL certificates, and storage classes.
3. The `config` subdirectory generates various configuration files and stores them in Kubernetes ConfigMaps. These configurations are used by different services within the EyeLevel application.
4. The database initialization script is created and stored, ready to be used when setting up the database for the first time.

## Key Variables and Settings

- `var.app_internal.namespace`: The Kubernetes namespace for the EyeLevel application.
- `var.cluster.kube_config_path`: Path to the Kubernetes configuration file.
- `var.admin`: Contains admin user details (API key, email, username).
- Service-specific variables for cache, database, file storage, search, and streaming services.

## Conditional Resource Creation in the Init Directory

This directory of the EyeLevel application uses a sophisticated system of conditional resource creation. This approach allows the infrastructure to be flexible, accommodating both new deployments and scenarios where some components already exist. By using conditional logic, the Terraform configurations can adapt to different environments and requirements without needing separate configuration files for each scenario.

## Mechanisms

### Conditional Expressions

#### 1. Storage Class Creation
Location: `init/add/app.tf`

```hcl
resource "kubernetes_storage_class_v1" "local_storage" {
  count = var.app_internal.pv_class != "empty" ? 1 : 0
  
  # ... resource configuration ...
}
```

**Logic**: This creates a storage class only if `var.app_internal.pv_class` is not "empty". It allows for skipping the creation of a storage class when it's not needed or when one already exists.

### Local Variables for Conditional Logic

#### 1. Cache Service
Location: `init/config/common.tf`

```hcl
locals {
  create_cache = var.cache_existing.addr == null || var.cache_existing.is_instance == null || var.cache_existing.port == null
  cache_settings = {
    addr        = coalesce(var.cache_existing.addr, "${var.cache_internal.service}.${var.app_internal.namespace}.svc.cluster.local")
    is_instance = coalesce(var.cache_existing.is_instance, var.cache_internal.is_instance)
    port        = coalesce(var.cache_existing.port, var.cache_internal.port)
  }
}
```

**Logic**: 
- `create_cache`: Determines if a new cache service should be created. It's true if any of the existing cache parameters (address, instance type, or port) are not provided.
- `cache_settings`: Uses the `coalesce` function to choose between existing values (if provided) and default internal values for the cache service configuration.

#### 2. Database
Location: `init/config/common.tf`

```hcl
locals {
  create_database = var.db_existing.port == null || var.db_existing.ro == null || var.db_existing.rw == null
  db_endpoints = {
    port = coalesce(var.db_existing.port, var.db_internal.port)
    ro   = coalesce(var.db_existing.ro, "${var.db_internal.service}-cluster-pxc-db-haproxy.${var.app_internal.namespace}.svc.cluster.local")
    rw   = coalesce(var.db_existing.rw, "${var.db_internal.service}-cluster-pxc-db-haproxy.${var.app_internal.namespace}.svc.cluster.local")
  }
}
```

**Logic**:
- `create_database`: Determines if a new database should be set up. It's true if any of the existing database parameters (port, read-only endpoint, read-write endpoint) are not provided.
- `db_endpoints`: Uses `coalesce` to set database endpoints, preferring existing values if available, otherwise using internal default values.

#### 3. File Storage
Location: `init/config/common.tf`

```hcl
locals {
  create_file = var.file_existing.base_domain == null || var.file_existing.bucket == null || var.file_existing.password == null || var.file_existing.port == null || var.file_existing.ssl == null
  file_settings = {
    base_domain = coalesce(var.file_existing.base_domain, "${var.file_internal.service}.${var.app_internal.namespace}.svc.cluster.local")
    bucket      = coalesce(var.file_existing.bucket, var.file.upload_bucket)
    dependency  = coalesce(var.file_existing.base_domain, "${var.file_internal.service}-tenant-hl.${var.app_internal.namespace}.svc.cluster.local")
    password    = coalesce(var.file_existing.password, var.file.password)
    port        = coalesce(var.file_existing.port, var.file_internal.port)
    ssl         = coalesce(var.file_existing.ssl, var.file_resources.ssl)
    username    = coalesce(var.file_existing.username, var.file.username)
  }
}
```

**Logic**:
- `create_file`: Determines if new file storage should be created. It's true if any of the existing file storage parameters are not provided.
- `file_settings`: Uses `coalesce` to set file storage settings, preferring existing values if available, otherwise using internal default values.

#### 4. Search Service
Location: `init/config/common.tf`

```hcl
locals {
  create_search = var.search_existing.base_domain == null || var.search_existing.base_url == null || var.search_existing.port == null
  search_settings = {
    base_domain = coalesce(var.search_existing.base_domain, "${var.search_internal.service}-cluster-master.${var.app_internal.namespace}.svc.cluster.local")
    base_url    = coalesce(var.search_existing.base_url, "https://${var.search_internal.service}-cluster-master.${var.app_internal.namespace}.svc.cluster.local:${var.search_internal.port}")
    port        = coalesce(var.search_existing.port, var.search_internal.port)
  }
}
```

**Logic**:
- `create_search`: Determines if a new search service should be set up. It's true if any of the existing search service parameters are not provided.
- `search_settings`: Uses `coalesce` to set search service settings, preferring existing values if available, otherwise using internal default values.

#### 5. Streaming Service
Location: `init/config/common.tf`

```hcl
locals {
  create_stream = var.stream_existing.base_domain == null || var.stream_existing.base_url == null || var.stream_existing.port == null
  stream_settings = {
    base_domain = coalesce(var.stream_existing.base_domain, "${var.stream_internal.service}-cluster-cluster-kafka-bootstrap.${var.app_internal.namespace}.svc.cluster.local")
    port        = coalesce(var.stream_existing.port, var.stream_internal.port)
  }
}
```

**Logic**:
- `create_stream`: Determines if a new streaming service should be created. It's true if any of the existing streaming service parameters are not provided.
- `stream_settings`: Uses `coalesce` to set streaming service settings, preferring existing values if available, otherwise using internal default values.

#### 6. Summary Service
Location: `init/config/common.tf`

```hcl
locals {
  create_summary = var.summary_existing.api_key == null || var.summary_existing.base_url == null
  summary_credentials = {
    api_key  = coalesce(var.summary_existing.api_key, var.admin.api_key)
    base_url = coalesce(var.summary_existing.base_url, "http://${var.summary_internal.service}-api.${var.app_internal.namespace}.svc.cluster.local")
  }
}
```

**Logic**:
- `create_summary`: Determines if a new summary service should be set up. It's true if either the existing API key or base URL is not provided.
- `summary_credentials`: Uses `coalesce` to set summary service credentials, preferring existing values if available, otherwise using internal default values.

#### 7. OpenShift Check
Location: `init/config/common.tf`

```hcl
locals {
  is_openshift = var.cluster.type == "openshift"
}
```

**Logic**: Determines if the cluster type is OpenShift. This can be used to apply OpenShift-specific configurations or resources when necessary.

### Conditional Creation

#### 1. Storage Class Creation
Location: `init/add/app.tf`

```hcl
resource "kubernetes_storage_class_v1" "local_storage" {
  count = var.app_internal.pv_class != "empty" ? 1 : 0
  
  # ... resource configuration ...
}
```

**Logic**: This resource is conditionally created based on the value of `var.app_internal.pv_class`. If it's not "empty", the storage class is created. This allows for flexibility in storage class management, enabling the use of pre-existing storage classes when available.

#### 2. Cache Service Creation
Location: `init/config/common.tf`

```hcl
locals {
  create_cache = var.cache_existing.addr == null || var.cache_existing.is_instance == null || var.cache_existing.port == null
}
```

**Logic**: Determines whether a new cache service should be created. If any of the existing cache parameters (address, instance type, or port) are not provided, a new cache service will be set up. This allows for integration with an existing cache service if all necessary details are provided.

#### 3. Database Creation
Location: `init/config/common.tf`

```hcl
locals {
  create_database = var.db_existing.port == null || var.db_existing.ro == null || var.db_existing.rw == null
}
```

**Logic**: Determines if a new database should be set up. If any of the existing database parameters (port, read-only endpoint, read-write endpoint) are not provided, a new database will be created. This allows for using an existing database if all necessary connection details are available.

#### 4. File Storage Creation
Location: `init/config/common.tf`

```hcl
locals {
  create_file = var.file_existing.base_domain == null || var.file_existing.bucket == null || var.file_existing.password == null || var.file_existing.port == null || var.file_existing.ssl == null
}
```

**Logic**: Determines if new file storage should be created. If any of the existing file storage parameters (base domain, bucket, password, port, SSL setting) are not provided, new file storage will be set up. This allows for integration with existing file storage systems if all necessary details are available.

#### 5. Search Service Creation
Location: `init/config/common.tf`

```hcl
locals {
  create_search = var.search_existing.base_domain == null || var.search_existing.base_url == null || var.search_existing.port == null
}
```

**Logic**: Determines if a new search service should be set up. If any of the existing search service parameters (base domain, base URL, port) are not provided, a new search service will be created. This allows for using an existing search service if all necessary connection details are available.

#### 6. Streaming Service Creation
Location: `init/config/common.tf`

```hcl
locals {
  create_stream = var.stream_existing.base_domain == null || var.stream_existing.base_url == null || var.stream_existing.port == null
}
```

**Logic**: Determines if a new streaming service should be created. If any of the existing streaming service parameters (base domain, base URL, port) are not provided, a new streaming service will be set up. This allows for integration with an existing streaming service if all necessary details are provided.

#### 7. Summary Service Creation
Location: `init/config/common.tf`

```hcl
locals {
  create_summary = var.summary_existing.api_key == null || var.summary_existing.base_url == null
}
```

**Logic**: Determines if a new summary service should be set up. If either the existing API key or base URL is not provided, a new summary service will be created. This allows for using an existing summary service if both the API key and base URL are available.

#### 8. Layout OCR Credentials ConfigMap Creation
Location: `init/config/config-files.tf`

```hcl
resource "kubernetes_config_map" "layout_ocr_credentials" {
  count = var.layout.ocr.credentials == "" || var.layout.ocr.type != "google" ? 0 : 1

  # ... resource configuration ...
}
```

**Logic**: This ConfigMap is conditionally created based on two factors:
1. The OCR credentials file path must not be empty.
2. The OCR type must be "google".
If both conditions are met, a ConfigMap containing the OCR credentials is created. This allows for flexibility in OCR service configuration, enabling the use of Google OCR when credentials are provided.

## Security Considerations

- SSL certificates are generated and stored securely in Kubernetes secrets.
- Sensitive information (like database passwords and API keys) is handled through variables and not hardcoded.