# Example `values.yaml`

## Example Service Configurations

The following `values.yaml` files have been provided with default configurations for services required by GroundX. They can be used as-is or modified according to your preferences.

| File Name                   | Description                                                                                                                              |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `values.db.cluster.yaml`    | Percona MySQL cluster configuration that can be used to create a MySQL cluster after the operator is installed                           |
| `values.db.operator.yaml`   | Percona MySQL operator configuration that can be used to install the Percona MySQL operator                                              |
| `values.file.operator.yaml` | MinIO operator configuration that can be used to install the MinIO operator                                                              |
| `values.file.tenant.yaml`   | MinIO tenant configuration that can be used to create MinIO tenant servers after the operator is installed                               |
| `values.search.yaml`        | OpenSearch operator and cluster configuration that can be used to create an OpenSearch cluster                                           |
| `values.stream.yaml`        | Strimzi Kafka operator configuration that can be used to install the Strimzi Kafka operator                                              |

## Example GroundX Configurations

The following example `values.yaml` files have been provided to demonstrate a variety of common GroundX deployment scenarios.

| File Name                   | Scenario                                                                                                                                 |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `values.aws.services.yaml`  | Replaces services with AWS equivalents                                                                                                   |
| `values.openai.yaml`        | Replaces hosted summary model with an OpenAI model (`eyelevel-gpu-summary` no longer needed)                                             |
| `values.existing.yaml`      | Replaces services with existing versions of the services, uses OpenAI vs a self hosted model (`eyelevel-gpu-summary` no longer needed)   |
| `values.minikube.yaml`      | Deploys GroundX to MiniKube with default configurations                                                                                  |
| `values.openshift.yaml`     | Deploys GroundX to OpenShift with default configurations                                                                                 |
