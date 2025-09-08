# Process Directory

This directory contains Terraform configuration for deploying and managing the Process service within a Kubernetes or OpenShift environment. The Process service is responsible for handling the main processing tasks in the EyeLevel application, integrating with the GroundX service.

## File Structure

- `process.tf`: Configuration for the Process service deployment

## Key Components

### Process Service (`process.tf`)

This file defines the Helm release for the Process service. It includes:

- Deployment of the Process service cluster
- Configuration of dependencies (GroundX service)
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments
- Service metadata configuration

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- The service depends on the GroundX service, ensure it's properly configured and deployed.

## Customization

To customize the Process service deployment:

1. Modify the `process_internal` variable in the main `variables.tf` file (parent directory) to adjust service configurations, image settings, or node selection.

Key variables for customization include:

- `process_internal.image`: Adjust the service image details (repository, tag, pull policy).
- `process_internal.node`: Specify the node type for deployment (e.g., "cpu").
- `process_internal.service`: Change the service name if needed.
- `process_internal.version`: Update the service version.

2. For more extensive changes, modify the `process.tf` file directly. For example:
   - Adjust the Helm chart path in the `chart` field if you have a custom chart.
   - Modify the `values` block to add or change service-specific configurations.

3. If adding new dependencies, ensure they are properly declared and configured in both the Process directory files and the main variables file.

4. Always test changes in a non-production environment before applying them to production.

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- GroundX service (configured in the parent directory)

## Integration with Other Services

The Process service primarily integrates with:
- GroundX service: It depends on the GroundX service for core functionality.

When making changes to the Process service, consider the potential impact on these integrated components and the overall system architecture.

## Security Considerations

- The service runs with specific user and group IDs, which are automatically set based on the cluster type (OpenShift or standard Kubernetes).
- Ensure that the necessary RBAC (Role-Based Access Control) permissions are in place for the service to interact with other components in the cluster.

## Maintenance

Regular maintenance tasks for the Process service may include:

1. Updating the service image to the latest version.
2. Adjusting resource allocations based on observed usage patterns.
3. Updating the Helm chart version if a new version is available.
4. Reviewing and updating security contexts and RBAC permissions as needed.