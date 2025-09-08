# Upload Directory

This directory contains Terraform configuration for deploying and managing the Upload service within a Kubernetes or OpenShift environment. The Upload service is responsible for handling file uploads in the EyeLevel application, integrating with the GroundX service.

## File Structure

- `upload.tf`: Configuration for the Upload service deployment

## Key Components

### Upload Service (`upload.tf`)

This file defines the Helm release for the Upload service. It includes:

- Deployment of the Upload service cluster
- Configuration of dependencies (GroundX service)
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments
- Service metadata configuration

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- The service depends on the GroundX service, ensure it's properly configured and deployed.

## Customization

To customize the Upload service deployment:

1. Modify the `upload_internal` variable in the main `variables.tf` file (parent directory) to adjust service configurations, image settings, or node selection.

Key variables for customization include:

- `upload_internal.image`: Adjust the service image details (repository, tag, pull policy).
- `upload_internal.node`: Specify the node type for deployment (e.g., "cpu").
- `upload_internal.service`: Change the service name if needed.
- `upload_internal.version`: Update the service version.

2. For more extensive changes, modify the `upload.tf` file directly. For example:
   - Adjust the Helm chart path in the `chart` field if you have a custom chart.
   - Modify the `values` block to add or change service-specific configurations.

3. If adding new dependencies, ensure they are properly declared and configured in both the Upload directory files and the main variables file.

4. Always test changes in a non-production environment before applying them to production.

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- GroundX service (configured in the parent directory)

## Integration with Other Services

The Upload service primarily integrates with:
- GroundX service: It depends on the GroundX service for core functionality.

When making changes to the Upload service, consider the potential impact on these integrated components and the overall system architecture.

## Security Considerations

- The service runs with specific user and group IDs, which are automatically set based on the cluster type (OpenShift or standard Kubernetes).
- Ensure that the necessary RBAC (Role-Based Access Control) permissions are in place for the service to interact with other components in the cluster.
- Consider implementing additional security measures for file uploads, such as virus scanning, file type restrictions, and size limits.