# Pre-Process Directory

This directory contains Terraform configuration for deploying and managing the Pre-Process service within a Kubernetes or OpenShift environment. The Pre-Process service is responsible for initial data processing tasks before the main processing pipeline, integrating with the GroundX service.

## File Structure

- `pre-process.tf`: Configuration for the Pre-Process service deployment

## Key Components

### Pre-Process Service (`pre-process.tf`)

This file defines the Helm release for the Pre-Process service. It includes:

- Deployment of the Pre-Process service cluster
- Configuration of dependencies (GroundX service)
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments
- Service metadata configuration

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- The service depends on the GroundX service, ensure it's properly configured and deployed.

## Customization

To customize the Pre-Process service deployment:

1. Modify the `pre_process_internal` variable in the main `variables.tf` file (parent directory) to adjust service configurations, image settings, or node selection.

Key variables for customization include:

- `pre_process_internal.image`: Adjust the service image details (repository, tag, pull policy).
- `pre_process_internal.node`: Specify the node type for deployment (e.g., "cpu").
- `pre_process_internal.service`: Change the service name if needed.
- `pre_process_internal.version`: Update the service version.

2. For more extensive changes, modify the `pre-process.tf` file directly. For example:
   - Adjust the Helm chart path in the `chart` field if you have a custom chart.
   - Modify the `values` block to add or change service-specific configurations.

3. If adding new dependencies, ensure they are properly declared and configured in both the Pre-Process directory files and the main variables file.

4. Always test changes in a non-production environment before applying them to production.

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- GroundX service (configured in the parent directory)

## Integration with Other Services

The Pre-Process service primarily integrates with:
- GroundX service: It depends on the GroundX service for further processing tasks.

When making changes to the Pre-Process service, consider the potential impact on these integrated components and the overall system architecture.

## Security Considerations

- The service runs with specific user and group IDs, which are automatically set based on the cluster type (OpenShift or standard Kubernetes).
- Ensure that the necessary RBAC (Role-Based Access Control) permissions are in place for the service to interact with other components in the cluster.