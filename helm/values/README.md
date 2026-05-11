# Example `values.yaml`

## Example Service Configurations

The following `values.yaml` files have been provided with default configurations for services required by GroundX. They can be used as-is or modified according to your preferences.

| Folder Name                 | Description                                                                                                                              |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `minio` | MinIO operator and tenant configurations that can be used to create a MinIO cluster |
| `nvidia` | NVIDIA GPU operator configurations |
| `opensearch` | OpenSearch operator and cluster configurations that can be used to create an OpenSearch cluster |
| `percona` | Percona operator and cluster configuration that can be used to create a MySQL cluster |
| `strimzi` | Strimzi operator configurations that can be used to install the Kafka operator |

## Example GroundX Configurations

The following example `values.yaml` files have been provided to demonstrate a variety of common GroundX deployment scenarios.

| File Name                   | Scenario                                                                                                                                 |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `values.aws.services.yaml`  | Replaces services with AWS equivalents                                                                                                   |
| `values.openai.yaml`        | Replaces hosted summary model with an OpenAI model (`eyelevel-gpu-summary` no longer needed)                                             |
| `values.existing.yaml`      | Replaces services with existing versions of the services, uses OpenAI vs a self hosted model (`eyelevel-gpu-summary` no longer needed)   |
