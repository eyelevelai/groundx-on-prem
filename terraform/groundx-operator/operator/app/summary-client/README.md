# Summary Client Directory

This directory contains Terraform configuration for deploying and managing the Summary Client service within a Kubernetes or OpenShift environment. The Summary Client service is responsible for interacting with the summarization functionality provided by the main Summary service, integrating with the GroundX service.

## File Structure

- `summary-client.tf`: Configuration for the Summary Client service deployment

## Key Components

### Summary Client Service (`summary-client.tf`)

This file defines the Helm release for the Summary Client service. It includes:

- Deployment of the Summary Client service cluster
- Configuration of dependencies (GroundX service)
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments
- Service metadata configuration

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- The service depends on the GroundX service, ensure it's properly configured and deployed.

## Customization

To customize the Summary Client service deployment:

1. Modify the `summary_client_internal` variable in the main `variables.tf` file (parent directory) to adjust service configurations, image settings, or node selection.

Key variables for customization include:

- `summary_client_internal.image`: Adjust the service image details (repository, tag, pull policy).
- `summary_client_internal.node`: Specify the node type for deployment (e.g., "cpu").
- `summary_client_internal.service`: Change the service name if needed.
- `summary_client_internal.version`: Update the service version.

2. For more extensive changes, modify the `summary-client.tf` file directly. For example:
   - Adjust the Helm chart path in the `chart` field if you have a custom chart.
   - Modify the `values` block to add or change service-specific configurations.

3. If adding new dependencies, ensure they are properly declared and configured in both the Summary Client directory files and the main variables file.

4. Always test changes in a non-production environment before applying them to production.

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- GroundX service (configured in the parent directory)

## Integration with Other Services

The Summary Client service primarily integrates with:
- GroundX service: It depends on the GroundX service for core functionality.
- Summary service: While not directly referenced in this file, the Summary Client likely interacts with the main Summary service.

When making changes to the Summary Client service, consider the potential impact on these integrated components and the overall system architecture.

## Security Considerations

- The service runs with specific user and group IDs, which are automatically set based on the cluster type (OpenShift or standard Kubernetes).
- Ensure that the necessary RBAC (Role-Based Access Control) permissions are in place for the service to interact with other components in the cluster.