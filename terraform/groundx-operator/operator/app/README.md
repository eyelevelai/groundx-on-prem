# EyeLevel App Directory

This directory contains the Terraform configuration for deploying and managing the entire EyeLevel application within a Kubernetes or OpenShift environment. The application consists of multiple microservices, each responsible for specific functionalities within the EyeLevel ecosystem.

## Directory Structure

- `groundx/`: Core service configuration
- `layout/`: Document layout analysis service
- `layout-webhook/`: Webhook service for layout processing
- `pre-process/`: Initial data processing service
- `process/`: Main data processing service
- `queue/`: Job queue management service
- `ranker/`: Content ranking service
- `summary/`: Text summarization service
- `summary-client/`: Client for interacting with the summary service
- `upload/`: File upload handling service

Each subdirectory contains its own `README.md` file with detailed information about the specific service.

## Key Components

### 1. GroundX

The core service of the EyeLevel application, responsible for coordinating other services and handling primary application logic.

### 2. Layout

Handles document layout analysis, including OCR (Optical Character Recognition) capabilities.

### 3. Layout Webhook

Manages webhook events related to document layout processing.

### 4. Pre-Process

Responsible for initial data preparation and processing before main processing tasks.

### 5. Process

Handles the main data processing tasks within the EyeLevel application.

### 6. Queue

Manages job queues and task distribution across the application.

### 7. Ranker

Provides content ranking functionality, likely using machine learning models.

### 8. Summary

Offers text summarization capabilities, potentially using AI models.

### 9. Summary Client

A client service for interacting with the Summary service.

### 10. Upload

Manages file uploads and associated storage within the application.

## Common Files

- `common.tf`: Shared provider configurations and local variables
- `helm_release.tf`: Helm provider configuration
- `locals.tf`: Local variable definitions
- `openshift.tf`: OpenShift-specific configurations
- `variables.tf`: Variable definitions for the entire project

## Important Notes

- The configuration supports both standard Kubernetes and OpenShift environments.
- Security contexts are automatically adjusted for OpenShift if detected.
- Many components can be configured to use existing external services or deploy internal ones.
- Ensure all necessary dependencies (e.g., databases, caches, file storage) are properly configured before deployment.

## Customization

Each service can be customized by modifying its respective variables in the `variables.tf` file. For service-specific customization details, refer to the README file in each service's subdirectory.

Common customization points include:
- Image repositories and tags
- Resource allocations
- Node selectors
- Service versions
- External service configurations (if using existing services)

## Dependencies

This configuration assumes the following are available and properly configured:
- Terraform
- Kubernetes or OpenShift cluster
- Helm
- Access to specified image repositories

## Security Considerations

- Review and adjust RBAC permissions for each service as needed.
- Ensure proper network policies are in place to control inter-service communication.
- Regularly update service images to include the latest security patches.
- Implement additional security measures for sensitive services (e.g., upload, database access).

## Monitoring and Logging

- Implement cluster-wide monitoring solutions to track the health and performance of all services.
- Set up centralized logging to aggregate logs from all services for easier troubleshooting and auditing.
- Consider implementing distributed tracing for better visibility into inter-service communications.

## Backup and Disaster Recovery

- Develop a comprehensive backup strategy covering all stateful services and critical data.
- Create and regularly test a disaster recovery plan that encompasses the entire application stack.
- Consider implementing multi-region deployments for high availability and disaster recovery.

## Performance Considerations

- Monitor resource usage across all services and adjust allocations as needed.
- Implement auto-scaling policies for services that may experience variable load.
- Optimize inter-service communication patterns to reduce latency and improve overall application performance.

## Maintenance

- Regularly update service images and Helm charts to their latest stable versions.
- Conduct periodic reviews of resource allocations and adjust based on observed usage patterns.
- Keep the Terraform configuration and associated scripts under version control.
- Maintain documentation for deployment processes, common issues, and resolution steps.