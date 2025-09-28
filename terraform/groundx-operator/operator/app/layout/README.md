# Layout Directory

This directory contains Terraform configuration files for deploying and managing the Layout service and its associated components within a Kubernetes or OpenShift environment. The Layout service is responsible for processing and analyzing document layouts, including OCR (Optical Character Recognition) capabilities.

## File Structure

- `layout-api.tf`: Configuration for the Layout API service
- `layout-inference.tf`: Configuration for the Layout Inference service
- `layout-ocr.tf`: Configuration for the Layout OCR service
- `layout-process.tf`: Configuration for the Layout Process service

## Key Components

### Layout API Service (`layout-api.tf`)

This file defines the Helm release for the Layout API service. It includes:
- Deployment of the Layout API service
- Configuration of cache dependencies
- Image and node selector settings
- Security context configuration, with special handling for OpenShift environments

### Layout Inference Service (`layout-inference.tf`)

Configures the Layout Inference service, which is responsible for machine learning inference tasks. It includes:
- Deployment of the Layout Inference service cluster
- Configuration of cache and file storage dependencies
- GPU memory allocation
- Image selection based on internet access
- Replica and timeout settings

### Layout OCR Service (`layout-ocr.tf`)

Sets up the Layout OCR service for text recognition in documents. Key features include:
- Conditional deployment based on OCR type (not deployed if Google OCR is used)
- Configuration of cache and file storage dependencies
- Image and node selector settings

### Layout Process Service (`layout-process.tf`)

Configures the Layout Process service, which handles document processing tasks. It includes:
- Deployment of the Layout Process service
- Configuration of cache and file storage dependencies
- Dynamic queue configuration based on OCR type
- Security context settings

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- The OCR service deployment is conditional based on the OCR type specified in the variables.
- GPU resources are allocated for the Inference service, ensure your cluster has available GPU nodes.
- The services rely on shared dependencies like cache and file storage, which should be properly configured in the main variables.

## Customization

To customize the Layout service deployment:

1. Modify the `layout`, `layout_internal`, and `layout_resources` variables in the main `variables.tf` file (parent directory) to adjust service configurations, resource allocations, or image settings.

Key variables for customization include:

- `layout.ocr`: Configure OCR settings, including the type of OCR service to use.
- `layout_internal.api.image`: Adjust the API service image details.
- `layout_internal.inference.image`: Modify the Inference service image settings.
- `layout_internal.nodes`: Specify node types for different components (api, inference, ocr, process).
- `layout_internal.models`: Configure model settings for figure and table detection.
- `layout_resources.inference`: Adjust GPU memory, replicas, and worker counts for the Inference service.

2. For more extensive changes, modify the relevant `.tf` files directly. For example:
   - Adjust the Helm chart paths in the `chart` field of each resource if you have custom charts.
   - Modify the `values` block in each resource to add or change service-specific configurations.

3. If adding new dependencies or services, ensure they are properly declared and configured in both the Layout directory files and the main variables file.

4. Always test changes in a non-production environment before applying them to production.

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- Shared services: Cache (Redis), File Storage (MinIO)
- GPU resources for the Inference service

## Integration with Other Services

The Layout services integrate with other components of the larger system:
- It uses the shared cache and file storage services defined in the parent directory.
- The Process service interacts with various queues for document processing tasks.
- The Inference service may require specific GPU resources, which should be available in your cluster.

When making changes to the Layout services, consider the potential impact on these integrated components and the overall system architecture.