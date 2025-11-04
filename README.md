# GroundX On-Prem/On-Cloud Kubernetes Infrastructure As Code

## Table of Contents

**[What is GroundX On-Prem?](#what-is-groundx-on-prem)**
- [GroundX Ingest Service](#groundx-ingest-service)
- [GroundX Search Service](#groundx-search-service)

**[Installing GroundX](#installing-groundx)**
- [Command Line Tool Dependencies](#command-line-tool-dependencies)
- [Cluster Requirements](#cluster-requirements)
  - [Background](#background)
    - [Node Groups](#node-groups)
    - [Required Compute Resources](#required-compute-resources)
      - [Chip Architecture](#chip-architecture)
      - [Supported GPUs](#supported-gpus)
      - [Total Recommended Resources](#total-recommended-resources)
      - [Node Group Resources](#node-group-resources)
        - [eyelevel-cpu-only](#eyelevel-cpu-only)
        - [eyelevel-cpu-memory](#eyelevel-cpu-memory)
        - [eyelevel-gpu-layout](#eyelevel-gpu-layout)
        - [eyelevel-gpu-ranker](#eyelevel-gpu-ranker)
        - [eyelevel-gpu-summary](#eyelevel-gpu-summary)
  - [Configure Node Groups](#configure-node-groups)
  - [Namespace](#namespace)
  - [PV Class](#pv-class)
  - [NVIDIA GPU Operator](#nvidia-gpu-operator)
    - [Installing in Microsoft Azure](#installing-in-microsoft-azure)
    - [Uninstalling the NVIDIA GPU Operator](#uninstalling-the-nvidia-gpu-operator)
- [Installing Services](#installing-services)
  - [Redis](#redis)
    - [Using an Existing Redis Cluster](#using-an-existing-redis-cluster)
    - [Deploying a Dedicated Redis Cluster](#deploying-a-dedicated-redis-cluster)
  - [MySQL](#mysql)
    - [Using an Existing MySQL Cluster](#using-an-existing-mysql-cluster)
    - [Deploying a Dedicated MySQL Cluster](#deploying-a-dedicated-mysql-cluster)
  - [MinIO](#minio)
    - [Using an Existing MinIO Cluster](#using-an-existing-minio-cluster)
    - [Using AWS S3](#using-aws-s3)
    - [Deploying a Dedicated MinIO Cluster](#deploying-a-dedicated-minio-cluster)
  - [OpenSearch](#opensearch)
    - [Using an Existing OpenSearch Cluster](#using-an-existing-opensearch-cluster)
    - [Deploying a Dedicated OpenSearch Cluster](#deploying-a-dedicated-opensearch-cluster)
  - [Kafka](#kafka)
    - [Using an Existing Kafka Cluster](#using-an-existing-kafka-cluster)
    - [Using AWS SQS](#using-aws-sqs)
    - [Deploying a Dedicated Kafka Cluster](#deploying-a-dedicated-kafka-cluster)
- [Installing the GroundX Application](#installing-the-groundx-application)

**[Using GroundX On-Prem](#using-groundx-on-prem)**
- [Get the API Endpoint](#get-the-api-endpoint)
- [Use the SDKs](#use-the-sdks)
- [Use the APIs](#use-the-apis)

**[Legacy Terraform Deployment](#legacy-terraform-deployment)**
- [Accessing Legacy Scripts](#accessing-legacy-scripts)

# What is GroundX On-Prem?

With this repository you can deploy GroundX RAG document ingestion and search capabilities to a Kubernetes cluster in a manner that can be isolated from any external dependencies.

GroundX delivers a unique approach to advanced RAG that consists of three interlocking systems:

1. **GroundX Ingest:** A state-of-the-art vision model trained on over 1M pages of enterprise documents. It delivers unparalleled document understanding and can be fine-tuned for your unique document sets.
2. **GroundX Store:** Secure, encrypted storage for source files, semantic objects, and vectors, ensuring your data is always protected.
3. **GroundX Search:** Built on OpenSearch, it combines text and vector search with a fine-tuned re-ranker model for precise, enterprise-grade results.

In head-to-head testing, GroundX significantly outperforms many popular RAG tools ([ref1](https://www.eyelevel.ai/post/most-accurate-rag), [ref2](https://www.eyelevel.ai/post/guide-to-document-parsing), [ref3](https://www.eyelevel.ai/post/do-vector-databases-lose-accuracy-at-scale)), especially with respect to complex documents at scale. GroundX is trusted by organizations like Air France, Dartmouth and Samsung with over 2 billion tokens ingested on our models.

GroundX On-Prem allows you to leverage GroundX within hardened and secure environments. GroundX On-Prem requires no external dependencies when running, meaning it can be used in air-gapped environments. Deployment consists of two key steps:

1. (Optional) Creation of Infrastructure on AWS via Terraform
2. Deployment of GroundX onto Kubernetes via Helm

Currently, creation of infrastructure via Terraform is only supported for AWS. However, with sufficient expertise GroundX can be deployed onto any pre-existing Kubernetes cluster.

This repo is in Open Beta. Feedback is appreciated and encouraged. To use the hosted version of GroundX visit [EyeLevel.ai](https://www.eyelevel.ai/). For white glove support in configuring this open source repo in your environment, or to access more performant and closed source versions of this repo, [contact us](https://www.eyelevel.ai/product/request-demo). To learn more about what GroundX is, and what it's useful for, you may be interested in the following resources:

- [A Video discussion the importance of parsing, and a comparison of several approaches](https://www.youtube.com/watch?v=7Vv64f1yI0I&t=1108s)
- [GroundX being used to power a multi-modal RAG application](https://www.youtube.com/watch?v=tIiqCG11hzQ)
- [GroundX being used to power a verbal AI Agent](https://www.youtube.com/watch?v=BL2G3C3_RZU&t=300s)

If you're deploying GroundX On-Prem on AWS, you might be interested in this [simple video guide for deploying on AWS](https://youtu.be/lFifBDDh6dc). To see how well GroundX understands your documents, check out our online testing tool:

| [![GX Ingest](doc/try-xray.png)](https://dashboard.eyelevel.ai/xray) |
| :--: |
| [Test your documents for free online](https://dashboard.eyelevel.ai/xray)|

## GroundX Ingest Service

The GroundX ingest service expects visually complex documents in a variety of formats. It analyzes those documents with several fine tuned models, converts the documents into a queryable representation which is designed to be understood by LLMs, and stores that information for downstream search.

![GroundX Ingest Service](doc/groundx-ingest.jpg)

## GroundX Search Service

Once documents have been processed via the ingest service they can be queried against via natural language queries. We use a custom configuration of Open Search which has been designed in tandem with the representations generated from the ingest service.

![GroundX Search Service](doc/groundx-search.jpg)

# Installing GroundX

## Command Line Tool Dependencies

You must have the following command line tools installed:

```markdown
- `bash` shell (version 4.0 or later recommended. AWS Cloud Shell has insufficient resources.)
- `kubectl` (or `oc`) configured to a namespace you can write to (e.g., `eyelevel`) ([Setup Docs](https://kubernetes.io/docs/tasks/tools/))
- `helm` v3.8+
```

## Cluster Requirements

In order to deploy GroundX On-Prem to your Kubernetes cluster, you must:

1. [Check](#required-compute-resources) that you have the required compute resources
2. [Configure or create](#configure-node-groups) appropriate node groups and nodes
3. Create a [Namespace](#namespace) or use an existing one
4. Create a [PV Class](#pv-class) or use an existing one
5. Install the [NVIDIA GPU Operator](#nvidia-gpu-operator) if it's not already installed

### Background

#### Node Groups

By default, the GroundX On-Prem pods deploy to nodes using node selector labels and tolerations. Here is an example from one of the k8 yaml configs:

```yaml
nodeSelector:
  node: "eyelevel-cpu-only"
tolerations:
  - key: "node"
    value: "eyelevel-cpu-only"
    effect: "NoSchedule"
```

Node labels are defined in the `values.yaml` and must be applied to appropriate nodes within your cluster. Default node label values are:

```text
eyelevel-cpu-memory
eyelevel-cpu-only
eyelevel-gpu-layout
eyelevel-gpu-ranker
eyelevel-gpu-summary
```

#### Required Compute Resources

##### Chip Architecture

The **publicly available** GroundX On-Prem Kubernetes pods are all built for `x86_64` architecture. Pods built for other architectures, such as `arm64`, are available upon customer request.

##### Supported GPUs

The GroundX On-Prem GPU pods are designed to run on NVIDIA GPUs with CUDA 12+. Other GPU types or older driver versions are not supported.

As part of the deployment, the [NVIDIA GPU Operator](#nvidia-gpu-operator) must be installed. We offer terraform scripts to deploy the [NVIDIA GPU Operator](#nvidia-gpu-operator) to your cluster, if you have not already done so.

The NVIDIA GPU operator should update your NVIDIA drivers and other software components needed to provision the GPU, so long as you have [supported NVIDIA hardware](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html) on the machine.

##### Total Recommended Resources

The GroundX On-Prem recommended resource requirements are:

```text
eyelevel-cpu-only
    80 GB     disk drive space
    8         CPU cores
    16 GB     RAM

eyelevel-cpu-memory
    20 GB     disk drive space
    4         CPU cores
    16 GB     RAM

eyelevel-gpu-layout
    16 GB     GPU memory
    75 GB     disk drive space
    4         CPU cores
    12 GB     RAM

eyelevel-gpu-ranker
    16 GB     GPU memory
    75 GB     disk drive space
    8         CPU cores
    30 GB     RAM

eyelevel-gpu-summary
    48 GB     GPU memory
    100 GB    disk drive space
    4         CPU cores
    30 GB     RAM
```

##### Node Group Resources

The GroundX On-Prem pods are grouped into 5 categories, based on resource requirements, and deploy as described in the [node group section](#node-groups).

These pods can be deployed to 5 different dedicated node groups, a single node group, or any combination in between, so long as the minimum resource requirements are met and the appropriate node labels are applied to the nodes.

The resource requirements are as follows:

###### eyelevel-cpu-only

Pods in this node group have minimal requirements on CPU, RAM, and disk drive space. They can run on virtually any machine with the [supported architecture](#chip-architecture).

The resource requirements for these pods are described in more detail in the [Total Recommended Resources](#total-recommended-resources) section above.

###### eyelevel-cpu-memory

Pods in this node group have a range of requirements on CPU, RAM, and disk drive space but can typically run on most machines with the [supported architecture](#chip-architecture).

CPU and memory intensive ingestion pipeline pods, such as `layout_ocr`, `layout_save`, and `pre_process`, will deploy to the **eyelevel-cpu-memory** nodes. The `layout_ocr` pod includes tesseract, which benefits from access to multiple vCPU cores.

The resource requirements for these pods are described in more detail in the [Total Recommended Resources](#total-recommended-resources) section above.

###### eyelevel-gpu-layout

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in more detail in the [Total Recommended Resources](#total-recommended-resources) section above.

The current configuration for this service assumes an NVIDIA GPU with 16 GB of GPU memory, 4 CPU cores, and at least 12 GB RAM. It deploys 1 pod with threads on this node (called `layout.inference.threads` in `values.yaml`) and claims the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator).

If your machine has different resources than this, you will need to modify `layout.inference` in your `values.yaml` using the per pod requirements described above to optimize for your node resources.

###### eyelevel-gpu-ranker

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in more detail in the [Total Recommended Resources](#total-recommended-resources) section above.

The current configuration for this service assumes an NVIDIA GPU with 16 GB of GPU memory, 4 CPU cores, and at least 30 GB RAM. It deploys 1 pod with 14 workers on this node (called `ranker.inference.workers` in `values.yaml`). It does not claim the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator) but uses 16 GB of GPU memory.

If your machine has different resources than this, you will need to modify `ranker.inference` in your `values.yaml` using the per pod requirements described above to optimize for your node resources.

###### eyelevel-gpu-summary

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in more detail in the [Total Recommended Resources](#total-recommended-resources) section above.

The current configuration for this service assumes an NVIDIA GPU with 48 GB of GPU memory, 4 CPU cores, and at least 30 GB RAM. It deploys 1 pod on this node (called `summary.inference.replicas.desired` in `values.yaml`). It does not claim the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator) but uses 24 GB of GPU memory per worker.

If your machine has different resources than this, you will need to modify `summary.inference` in your `values.yaml` using the per pod requirements described above to optimize for your node resources.

### Configure Node Groups

As mentioned in the [node groups](#node-groups) section, node labels are defined in [values.yaml](./values.yaml) and must be applied to appropriate nodes within your cluster. Default node label values include:

```text
eyelevel-cpu-memory
eyelevel-cpu-only
eyelevel-gpu-layout
eyelevel-gpu-ranker
eyelevel-gpu-summary
```

Multiple node labels can be applied to the same node group, so long as resources are available as described in the [total recommended resource](#total-recommended-resources) and [node group resources](#node-group-resources) sections.

However, **all** node labels must exist on **at least 1 node group** within your cluster. The label should be applied with a string key named `node` and an enumerated string value from the list above.

#### Applying Custom Node Groups

##### Default Labels

If you use the **default labels** described in [Configure Node Groups](#configure-node-groups), you **do not** need to do anything else. The helm chart assumes these default values during the deployment.

##### Custom Labels

If you use **custom labels**, you must update the following values during GroundX deployment:

```yaml
cache.node
cache.metrics.node
groundx.node
layout.api.node
layout.correct.node
layout.inference.node
layout.map.node
layout.ocr.node
layout.process.node
layout.save.node
layoutWebhook.node
preProcess.node
process.node
queue.node
ranker.api.node
ranker.inference.node
summary.api.node
summary.inference.node
summaryClient.node
upload.node
```

See the values.yaml [README.md](helm/README.md) for more information about these values.

You will also need to update values for any services you deploy as well.

### Namespace

You must have a namespace where the GroundX application can be installed. If you need to create one, you can do so by running the following command:

```bash
kubectl create namespace eyelevel
```

This will create a namespace called `eyelevel` where GroundX pods will be installed.

The default `values.yaml` namespace assumes a name of `eyelevel`. If you choose to use a different namespace name, you will have to update the `values.yaml` file accordingly.

### PV Class

GroundX requires a PV class for some of the pods. If you have not created one, we have included a chart that will create one. You can run it with the following comand:

```bash
helm install groundx-storageclass \
  groundx/groundx-storageclass \
  -n eyelevel
```

### NVIDIA GPU Operator

Some of the GroundX pods require access to an NVIDIA GPU. The easiest way to ensure access is to install the NVIDIA GPU Operator, which will ensure the appropriate drivers and libraries are installed on the GPU nodes.

If you'd like to install the NVIDIA GPU Operator to your cluster, use the following commands below:

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

helm install nvidia-gpu-operator \
  nvidia/gpu-operator \
  -n nvidia-gpu-operator \
  --create-namespace \
  --atomic \
  -f helm/values/values.nvidia.yaml
```

#### Installing in Microsoft Azure

If you're installing the NVIDIA GPU operator into Microsoft Azure, be sure to set the `runtimeClass` to `nvidia-container-runtime`. We have included an example yaml that shows how to do this at `helm/values/values.nvidia.aks.yaml`.

If you'd like to install the NVIDIA GPU Operator with this AKS-specific yaml, use the following commands below:

```bash
helm install nvidia-gpu-operator nvidia/gpu-operator \
  -n nvidia-gpu-operator \
  --create-namespace \
  --atomic \
  -f helm/values/values.nvidia.aks.yaml
```

## Installing Services

### Redis

#### Using an Existing Redis Cluster

If you wish to use an existing redis cache, you must configure the `cache.existing` and `cache.metrics.existing` parameters in your `values.yaml`.

#### Deploying a Dedicated Redis Cluster

If you'd like to install redis to your cluster, instances will be automatically created during the application installation for you so long as `cache.existing` is an empty dictionary and `cache.enabled` is `true`.

### MySQL

#### Using an Existing MySQL Cluster

If you wish to use an existing MySQL cluster, you must configure the `db.existing` parameters in your `values.yaml`.

#### Deploying a Dedicated MySQL Cluster

If you'd like to install MySQL to your cluster, use the following commands below:

```bash
helm repo add percona https://percona.github.io/percona-helm-charts/
helm repo update

helm install db-operator \
  percona/pxc-operator \
  -n eyelevel \
  -f helm/values/values.db.operator.yaml
helm install db-cluster \
  percona/pxc-db \
  -n eyelevel \
  -f helm/values/values.db.cluster.yaml
```

### MinIO

#### Using an Existing MinIO Cluster

If you wish to use an existing MinIO cluster, you must configure the `file.existing` parameters in your `values.yaml`.

#### Using AWS S3

If you wish to use an existing AWS S3 bucket, you must configure the `file.existing` parameters in your `values.yaml` **and** set `file.serviceType` to `s3`.

#### Deploying a Dedicated MinIO Cluster

If you'd like to install MinIO to your cluster, use the following commands below:

```bash
helm repo add minio-operator https://operator.min.io/
helm repo update

helm install minio-operator \
  minio-operator/operator \
  -n eyelevel \
  -f helm/values/values.file.operator.yaml
helm install minio-cluster \
  minio-operator/tenant \
  -n eyelevel \
  -f helm/values/values.file.tenant.yaml
```

### OpenSearch

#### Using an Existing OpenSearch Cluster

If you wish to use an existing OpenSearch cluster, you must configure the `search.existing` parameters in your `values.yaml`.

#### Deploying a Dedicated OpenSearch Cluster

If you'd like to install OpenSearch to your cluster, use the following commands below:

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm install opensearch opensearch/opensearch -n eyelevel -f helm/values/values.search.yaml --version 2.23.1
```

### Kafka

#### Using an Existing Kafka Cluster

If you wish to use an existing Kafka cluster, you must configure the `stream.existing` parameters in your `values.yaml`.

#### Using AWS SQS

If you wish to use existing AWS SQS queues, you must configure the `stream.existing` parameters in your `values.yaml` **and** set `stream.serviceType` to `sqs`.

#### Deploying a Dedicated Kafka Cluster

If you'd like to install Kafka to your cluster, use the following commands below:

```bash
helm install stream-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  -n eyelevel \
  -f helm/values/values.stream.yaml
```

Once the operator is ready, run the following command:

```bash
helm install groundx-kafka-cluster \
  groundx/groundx-strimzi-kafka-cluster \
  -n eyelevel
```

## Installing the GroundX Application

### Pre-Requisites

You must have completed the following steps before attempting to install the GroundX application:

- [Configure Node Groups](#configure-node-groups)
- Create or select a [Namespace](#namespace)
- Create or select a [PV Class](#pv-class)
- Install the [NVIDIA GPU Operator](#nvidia-gpu-operator)
- [Install Services](#installing-services)

### Configuration

Instructions on how to configure GroundX On-Prem can by found in the main [README.md](helm/README.md). A set of example configurations can be found at [helm/values](helm/values).

For a GroundX deployment with default settings:

1. Copy `sample.values.yaml` to something like `values.yaml`
2. We minimally suggest updating the following values:

```yaml
groundxKey      # a valid GroundX API key, to be used to look up licensing information
admin.apiKey    # admin values are associated with
admin.username  # the admin account for your deployment
admin.email
admin.password
cluster.pvClass # an existing storage class
cluster.type    # type of Kubernetes cluster
```

**Note**: `admin.apiKey` and `admin.username` must be valid UUIDs. We provide a helper script to generate random UUIDs. You can run it using thefollowing command:

```bash
bin/uuid
```

### Helm Installation

To install GroundX, add the chart repo to helm by running the following commands:

```bash
helm repo add groundx https://registry.groundx.ai/helm
helm repo update
```

Once the repo is added, you can install the GroundX application by running the following command:

```bash
helm install groundx \
  groundx/groundx \
  -n eyelevel \
  -f values.yaml
```

Replace `values.yaml` with the path to the `values.yaml` file you created in the previous [Configuration](#configuration) step.

# Using GroundX On-Prem

## Get the API Endpoint

Once the setup is complete, run:

```bash
kubectl -n eyelevel get svc groundx
```

The API endpoint will be the external IP associated with the GroundX load balancer.

For instance, the "external IP" might resemble the following:

```bash
EXTERNAL-IP
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxx.us-east-2.elb.amazonaws.com
```

## Use the SDKs

The [API endpoint](#get-the-api-endpoint), in conjuction with the `admin.api_key` defined during deployment, can be used to configure the GroundX SDK to communicate with your On-Prem instance of GroundX.

Note: you must append `/api` to your [API endpoint](#get-the-api-endpoint) in the SDK configuration.

```python
from groundx import GroundX

external_ip = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxx.us-east-2.elb.amazonaws.com'
api_key="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

client = GroundX(api_key=api_key, base_url=f"http://{external_ip}/api")
```

```typescript
import { GroundXClient } from "groundx";

const external_ip = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxx.us-east-2.elb.amazonaws.com'

const groundx = new GroundXClient({
  apiKey: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  environment: `http://${external_ip}/api`;,
});
```

## Use the APIs

The [API endpoint](#get-the-api-endpoint), in conjuction with the `admin.api_key` defined during deployment, can be used to interact with your On-Prem instance of GroundX.

All of the methods and operations described in the [GroundX documentation](https://documentation.groundx.ai/reference) are supported with your On-Prem instance of GroundX. You simply have to substitute `https://api.groundx.ai` with your [API endpoint](#get-the-api-endpoint).

# Legacy Terraform Deployment

As of November 4, 2025, we have migrated to a pure helm release deployment. The previous hybrid terraform-helm approach is no longer supported.

## Accessing Legacy Scripts
If you would like to access the legacy terraform scripts, they can be pulled from [legacy-terraform-deployment](https://github.com/eyelevelai/groundx-on-prem/releases/tag/legacy-terraform-deployment).
