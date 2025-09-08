# Services Directory Documentation

The `services` directory contains the infrastructure-as-code (IaC) configurations for deploying and managing various services within the EyeLevel application ecosystem. Each subdirectory represents a distinct service or component, managed through Terraform and Helm charts.

## Directory Structure

```
services/
├── cache/
├── db/
├── file/
├── search/
├── stream/
```

## Common Files

Each service subdirectory typically contains the following files:

- `variables.tf`: Defines input variables for the service.
- `main.tf` or service-specific `.tf` files (e.g., `redis.tf`, `mysql.tf`): Contains the main Terraform resource definitions.
- `outputs.tf`: Specifies the outputs from the Terraform module.

## Service Descriptions

### 1. Cache Service (Redis)

**Directory**: `cache/`

**Purpose**: Manages Redis cache deployment for the EyeLevel application.

**Key Features**:
- Supports both existing Redis instances and new deployments.
- Configurable resource allocation and replication.
- OpenShift compatibility.

**Main Configuration Parameters**:
- `cache_existing`: Settings for existing Redis cache.
- `cache_internal`: Internal Redis deployment settings.
- `cache_resources`: Resource allocation for Redis.

### 2. Database Service (MySQL)

**Directory**: `db/`

**Purpose**: Manages MySQL database deployment using Percona XtraDB Cluster.

**Key Features**:
- Supports both existing databases and new PXC deployments.
- Configurable backup, monitoring, and high availability settings.
- Separate proxy (HAProxy) configuration for load balancing.

**Main Configuration Parameters**:
- `db_existing`: Settings for existing database.
- `db_internal`: Internal PXC deployment settings.
- `db_resources`: Resource allocation for database and proxy.

### 3. File Storage Service (MinIO)

**Directory**: `file/`

**Purpose**: Manages MinIO object storage deployment for file handling.

**Key Features**:
- Supports both existing MinIO instances and new deployments.
- Configurable storage pools and server settings.
- SSL support for secure communications.

**Main Configuration Parameters**:
- `file_existing`: Settings for existing MinIO instance.
- `file_internal`: Internal MinIO deployment settings.
- `file_resources`: Resource allocation and storage configuration.

### 4. Search Service (OpenSearch)

**Directory**: `search/`

**Purpose**: Manages OpenSearch deployment for search functionality.

**Key Features**:
- Supports both existing OpenSearch instances and new deployments.
- Configurable cluster settings and resource allocation.
- Integration with EyeLevel application for search capabilities.

**Main Configuration Parameters**:
- `search_existing`: Settings for existing OpenSearch instance.
- `search_internal`: Internal OpenSearch deployment settings.
- `search_resources`: Resource allocation for OpenSearch cluster.

### 5. Stream Service (Apache Kafka)

**Directory**: `stream/`

**Purpose**: Manages Apache Kafka deployment using the Strimzi operator for stream processing.

**Key Features**:
- Supports both existing Kafka instances and new deployments.
- Configurable cluster settings, including ZooKeeper.
- Scalable and high-performance message streaming.

**Main Configuration Parameters**:
- `stream_existing`: Settings for existing Kafka instance.
- `stream_internal`: Internal Kafka deployment settings.
- `stream_resources`: Resource allocation for Kafka and ZooKeeper.

## Global Configuration

The `variables.tf` file in the root of the `services` directory contains global configurations that apply across all services, including:

- `admin`: Administrator account information.
- `app`: General application settings like namespace.
- `cluster`: Kubernetes cluster information.