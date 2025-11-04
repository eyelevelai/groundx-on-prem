# GroundX Directory

This directory contains Terraform configuration files for deploying and managing the GroundX service and its associated infrastructure components. The configuration is designed to work with Kubernetes clusters, with specific support for OpenShift environments.

## File Structure

- `common.tf`: Common provider configurations and local variables
- `groundx.tf`: GroundX service deployment configuration
- `helm_release.tf`: Helm provider configuration
- `load-balancer.tf`: Load balancer and route configurations
- `locals.tf`: Local variable definitions
- `openshift.tf`: OpenShift-specific configurations
- `variables.tf`: Variable definitions for the entire project

## Key Components

### GroundX Service (`groundx.tf`)

This file defines the Helm release for the GroundX service. It includes:
- Deployment of the GroundX service cluster
- Configuration of dependencies (cache, database, file storage, search, and stream services)
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments

### Load Balancer (`load-balancer.tf`)

Configures the load balancer or route for the GroundX service:
- For non-OpenShift clusters: Deploys a load balancer
- For OpenShift clusters: Creates a route

### Common Configurations (`common.tf`)

Contains shared provider configurations and local variables, including:
- Kubernetes provider setup
- Flags for determining the cluster type (OpenShift or not)
- Settings for various services like cache, database, file storage, search, and stream

### Variables (`variables.tf`)

Defines all the variables used across the project, including:
- Global settings (admin info, app namespace)
- Cluster configuration
- Service-specific settings (cache, database, file storage, search, stream, etc.)
- Resource allocations for various components

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- Many components (cache, database, file storage, etc.) can be configured to use existing external services or deploy internal ones.
- Resource allocations and replica counts can be adjusted in the variables file to suit different scale requirements.
- The project uses Helm for deploying most components, ensure you have Helm properly configured in your environment.

## Customization

The GroundX deployment can be extensively customized by modifying variables in the `variables.tf` file. Here's a detailed guide on key variables that can be adjusted and their associated logic:

### Global Settings

1. `admin`: Modify administrator account information.
   - `api_key`: Change the API key for admin access.
   - `email` and `password`: Update admin credentials.

2. `app`: Adjust application-wide settings.
   - `namespace`: Change the Kubernetes namespace for deployment.
   - `pv_class`: Modify the persistent volume class used.

### Cluster Configuration

3. `cluster`: Customize cluster-specific settings.
   - `internet_access`: Toggle if the cluster has external internet access.
   - `kube_config_path`: Update the path to your kubeconfig file.
   - `type`: Set to "openshift" for OpenShift clusters, or another value for standard Kubernetes.

### GroundX Service

4. `groundx`: Modify GroundX service settings.
   - `load_balancer.port`: Change the load balancer port.

5. `groundx_internal`: Adjust internal GroundX configurations.
   - `image`: Update the Docker image details (repository, tag, pull policy).
   - `node`: Specify the node type for deployment (e.g., "cpu", "gpu").
   - `type`: Set to "all" or "search" based on deployment requirements.

### Cache Service

6. `cache_existing`: Configure an external Redis cache instead of deploying internally.
   - Set `addr`, `is_instance`, and `port` to use an existing cache.

7. `cache_internal`: Customize internal Redis deployment.
   - Modify `image`, `port`, `version`, etc., for the Redis setup.

8. `cache_resources`: Adjust compute resources for the cache.
   - Change `replicas`, CPU and memory `limits` and `requests`.

### Database Service

9. `db`: Modify database credentials and names.

10. `db_existing`: Configure an external database instead of deploying internally.
    - Set `port`, `ro` (read-only endpoint), and `rw` (read-write endpoint).

11. `db_internal`: Customize internal database deployment.
    - Adjust `chart`, `version`, `port`, etc., for the database setup.

12. `db_resources`: Fine-tune database compute resources.
    - Modify `proxy` settings, `pv_size`, `replicas`, CPU and memory allocations.

### File Storage Service

13. `file`: Update file storage service credentials and bucket names.

14. `file_existing`: Configure an external file storage service (e.g., MinIO) instead of deploying internally.
    - Set `base_domain`, `bucket`, `password`, `port`, `ssl`, and `username`.

15. `file_internal`: Customize internal file storage deployment.
    - Adjust `chart_base`, `port`, `version`, etc., for the file storage setup.

16. `file_resources`: Fine-tune file storage compute resources.
    - Modify `pool_size`, `pool_servers`, `ssl` settings, CPU and memory allocations.

### Search Service

17. `search`: Update search service credentials and index names.

18. `search_existing`: Configure an external search service (e.g., OpenSearch) instead of deploying internally.
    - Set `base_domain`, `base_url`, and `port`.

19. `search_internal`: Customize internal search service deployment.
    - Adjust `chart`, `image`, `port`, `version`, etc., for the search setup.

20. `search_resources`: Fine-tune search service compute resources.
    - Modify `pv_size`, `replicas`, CPU and memory allocations.

### Stream Service

21. `stream_existing`: Configure an external streaming service (e.g., Kafka) instead of deploying internally.
    - Set `base_domain`, `base_url`, and `port`.

22. `stream_internal`: Customize internal streaming service deployment.
    - Adjust `chart`, `port`, `version`, etc., for the stream setup.

23. `stream_resources`: Fine-tune streaming service compute resources.
    - Modify `partitions`, `retention_bytes`, `segment_bytes`, replica counts, and storage sizes.

### Layout, Ranker, and Summary Services

24. `layout_internal`, `ranker_internal`, `summary_internal`: Customize these auxiliary services.
    - Adjust `image`, `nodes`, `inference` settings for each service.

25. `layout_resources`, `ranker_resources`, `summary_resources`: Fine-tune compute resources for these services.
    - Modify GPU memory, replicas, and worker counts.