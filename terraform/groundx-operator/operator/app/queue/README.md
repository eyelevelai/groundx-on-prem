# Queue Directory

This directory contains Terraform configuration for deploying and managing the Queue service within a Kubernetes or OpenShift environment. The Queue service is responsible for managing job queues and task distribution in the EyeLevel application, integrating with the GroundX service.

## File Structure

- `queue.tf`: Configuration for the Queue service deployment

## Key Components

### Queue Service (`queue.tf`)

This file defines the Helm release for the Queue service. It includes:

- Deployment of the Queue service cluster
- Configuration of dependencies (GroundX service)
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments
- Service metadata configuration

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- The service depends on the GroundX service, ensure it's properly configured and deployed.

## Customization

To customize the Queue service deployment:

1. Modify the `queue_internal` variable in the main `variables.tf` file (parent directory) to adjust service configurations, image settings, or node selection.

Key variables for customization include:

- `queue_internal.image`: Adjust the service image details (repository, tag, pull policy).
- `queue_internal.node`: Specify the node type for deployment (e.g., "cpu").
- `queue_internal.service`: Change the service name if needed.
- `queue_internal.version`: Update the service version.

2. For more extensive changes, modify the `queue.tf` file directly. For example:
   - Adjust the Helm chart path in the `chart` field if you have a custom chart.
   - Modify the `values` block to add or change service-specific configurations.

3. If adding new dependencies, ensure they are properly declared and configured in both the Queue directory files and the main variables file.

4. Always test changes in a non-production environment before applying them to production.

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- GroundX service (configured in the parent directory)

## Integration with Other Services

The Queue service primarily integrates with:
- GroundX service: It depends on the GroundX service for core functionality.

When making changes to the Queue service, consider the potential impact on these integrated components and the overall system architecture.

## Security Considerations

- The service runs with specific user and group IDs, which are automatically set based on the cluster type (OpenShift or standard Kubernetes).
- Ensure that the necessary RBAC (Role-Based Access Control) permissions are in place for the service to interact with other components in the cluster.