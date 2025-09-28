# Summary Directory

This directory contains Terraform configuration for deploying and managing the Summary service within a Kubernetes or OpenShift environment. The Summary service consists of two main components: an API service and an Inference service. These components work together to provide summarization functionality for the EyeLevel application.

## File Structure

- `summary-api.tf`: Configuration for the Summary API service deployment
- `summary-inference.tf`: Configuration for the Summary Inference service deployment

## Key Components

### Summary API Service (`summary-api.tf`)

This file defines the Helm release for the Summary API service. It includes:

- Conditional deployment based on the `create_summary` flag
- Deployment of the Summary API service cluster
- Configuration of dependencies (Cache service)
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments
- Service metadata configuration

### Summary Inference Service (`summary-inference.tf`)

This file defines the Helm release for the Summary Inference service. It includes:

- Conditional deployment based on the `create_summary` flag
- Deployment of the Summary Inference service cluster
- Configuration of dependencies (Cache service)
- GPU memory allocation
- Image selection based on internet access
- Node selector settings for GPU nodes
- Replica configuration
- Security context configuration, with special handling for OpenShift environments
- Service metadata configuration

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- The Inference service requires GPU resources, ensure your cluster has available GPU nodes.
- The services depend on the Cache service, ensure it's properly configured and deployed.
- Deployment of both services is conditional based on the `create_summary` flag, which is determined by the presence of existing summary settings.

## Customization

To customize the Summary service deployment:

1. Modify the `summary_internal`, `summary_resources`, and `summary_existing` variables in the main `variables.tf` file (parent directory) to adjust service configurations, image settings, or resource allocations.

Key variables for customization include:

- `summary_internal.api.image`: Adjust the API service image details.
- `summary_internal.inference.image`: Modify the Inference service image settings.
- `summary_internal.nodes`: Specify node types for different components (api, inference).
- `summary_internal.inference.model`: Set the machine learning model to be used.
- `summary_resources.inference`: Adjust GPU memory, replicas, and worker counts for the Inference service.
- `summary_existing`: Configure to use an existing summary service outside the cluster.

2. For more extensive changes, modify the `summary-api.tf` and `summary-inference.tf` files directly. For example:
   - Adjust the Helm chart paths in the `chart` field if you have custom charts.
   - Modify the `values` blocks to add or change service-specific configurations.

3. If adding new dependencies, ensure they are properly declared and configured in both the Summary directory files and the main variables file.

4. Always test changes in a non-production environment before applying them to production.

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- Cache service (configured in the parent directory)
- GPU resources for the Inference service

## Integration with Other Services

The Summary services primarily integrate with:
- Cache service: Both API and Inference services depend on the Cache service.

When making changes to the Summary services, consider the potential impact on these integrated components and the overall system architecture.

## Security Considerations

- The services run with specific user IDs, which are automatically set based on the cluster type (OpenShift or standard Kubernetes).
- Ensure that the necessary RBAC (Role-Based Access Control) permissions are in place for the services to interact with other components in the cluster.