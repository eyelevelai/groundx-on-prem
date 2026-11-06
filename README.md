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
- [Installing Services](#installing-services)
  - [Redis](#redis)
    - [Using an Existing Redis Cluster](#using-an-existing-redis-cluster)
    - [Deploying a Dedicated Redis Cluster](#deploying-a-dedicated-redis-cluster)
  - [MySQL](#mysql)
    - [Using an Existing MySQL Cluster](#using-an-existing-mysql-cluster)
    - [Deploying a Dedicated MySQL Cluster](#deploying-a-dedicated-mysql-cluster)
  - [MinIO AIStor](#minio-aistor)
    - [Using an Existing MinIO Cluster](#using-an-existing-minio-cluster)
    - [Using AWS S3](#using-aws-s3)
    - [Using S4](#using-s4)
    - [Deploying a Dedicated AIStor Object Store](#deploying-a-dedicated-aistor-object-store)
    - [Object Keys That Start with a Slash](#object-keys-that-start-with-a-slash)
    - [Upgrading an Existing MinIO Install to AIStor](#upgrading-an-existing-minio-install-to-aistor)
    - [Restoring Community MinIO from the Pre-Upgrade Snapshot](#restoring-community-minio-from-the-pre-upgrade-snapshot)
    - [Staying on Community MinIO](#staying-on-community-minio)
  - [OpenSearch](#opensearch)
    - [Using an Existing OpenSearch Cluster](#using-an-existing-opensearch-cluster)
    - [Deploying a Dedicated OpenSearch Cluster](#deploying-a-dedicated-opensearch-cluster)
  - [Kafka](#kafka)
    - [Using an Existing Kafka Cluster](#using-an-existing-kafka-cluster)
    - [Using AWS SQS](#using-aws-sqs)
    - [Deploying a Dedicated Kafka Cluster](#deploying-a-dedicated-kafka-cluster)
- [Installing the GroundX Application](#installing-the-groundx-application)

**[Autoscaling & Monitoring](#autoscaling--monitoring)**
- [Enabling Autoscaling (HPA)](#enabling-autoscaling-hpa)
  - [Per-Pod HPA Control](#per-pod-hpa-control)
- [How Autoscaling Works](#how-autoscaling-works)
- [Enabling the Custom Metrics Server](#enabling-the-custom-metrics-server)
- [Prometheus Integration (Optional)](#prometheus-integration-optional)
- [Using Simulated LLM Responses (Optional)](#using-simulated-llm-responses-optional)

**[Using GroundX On-Prem](#using-groundx-on-prem)**
- [Get the API Endpoint](#get-the-api-endpoint)
- [Use the SDKs](#use-the-sdks)
- [Use the APIs](#use-the-apis)

**[Terraform Deployment (terraform/aws/)](#terraform-deployment-terraformaws)**
- [Accessing Legacy Scripts](#accessing-legacy-scripts)
- [Optional EKS Node Diagnostics](#optional-eks-node-diagnostics)
- [EKS Cluster Version Configuration](#eks-cluster-version-configuration)

# What is GroundX On-Prem?

With this repository you can deploy GroundX RAG document ingestion and search capabilities to a Kubernetes cluster in a manner that can be isolated from any external dependencies.

GroundX delivers a unique approach to advanced RAG that consists of three interlocking systems:

1. **GroundX Ingest:** A state-of-the-art vision model trained on over 1M pages of enterprise documents. It delivers unparalleled document understanding and can be fine-tuned for your unique document sets.
2. **GroundX Store:** Secure, encrypted storage for source files, semantic objects, and vectors, with access controls and encryption configured for your deployment.
3. **GroundX Search:** Built on OpenSearch, it combines text and vector search with a fine-tuned re-ranker model for precise, enterprise-grade results.

In head-to-head testing, GroundX significantly outperforms many popular RAG tools ([ref1](https://www.eyelevel.ai/post/most-accurate-rag), [ref2](https://www.eyelevel.ai/post/guide-to-document-parsing), [ref3](https://www.eyelevel.ai/post/do-vector-databases-lose-accuracy-at-scale)), especially with respect to complex documents at scale. GroundX is trusted by organizations like Air France, Dartmouth and Samsung with over 2 billion tokens ingested on our models.

GroundX On-Prem allows you to leverage GroundX within hardened and secure environments. Air-gapped deployments require self-hosted models and services, with images, model files and other dependencies prepared in advance. Deployment consists of two key steps:

1. (Optional) Creation of Infrastructure on AWS via Terraform
2. Deployment of GroundX onto Kubernetes via Helm

Currently, creation of infrastructure via Terraform is only supported for AWS. However, with sufficient expertise GroundX can be deployed onto any pre-existing Kubernetes cluster.

GroundX On-Prem is generally available. Feedback is appreciated and encouraged. To use the hosted version of GroundX visit [EyeLevel.ai](https://www.eyelevel.ai/). For white glove support in configuring this open source repo in your environment, or to access more performant and closed source versions of this repo, [contact us](https://www.eyelevel.ai/product/request-demo). To learn more about what GroundX is, and what it's useful for, you may be interested in the following resources:

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

- `bash` shell (version 4.0 or later recommended. AWS Cloud Shell has insufficient resources.)
- `kubectl` (or `oc`) configured to a namespace you can write to (e.g., `eyelevel`) ([Setup Docs](https://kubernetes.io/docs/tasks/tools/))
- `helm` v3.8+

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
  eyelevel_node: "eyelevel-cpu-only"
tolerations:
  - key: "eyelevel_node"
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

As part of the deployment, the [NVIDIA GPU Operator](#nvidia-gpu-operator) must be installed. Install it with the Helm commands below if you have not already done so.

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

Note: in many cloud Kubernetes services, such as EKS, you must use a node image that supports GPUs (e.g. AL2023_x86_64_NVIDIA).

###### eyelevel-gpu-ranker

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in more detail in the [Total Recommended Resources](#total-recommended-resources) section above.

The current configuration for this service assumes an NVIDIA GPU with 16 GB of GPU memory, 4 CPU cores, and at least 30 GB RAM. It deploys 1 pod with 14 workers on this node (called `ranker.inference.workers` in `values.yaml`). It does not claim the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator) but uses 16 GB of GPU memory.

If your machine has different resources than this, you will need to modify `ranker.inference` in your `values.yaml` using the per pod requirements described above to optimize for your node resources.

Note: in many cloud Kubernetes services, such as EKS, you must use a node image that supports GPUs (e.g. AL2023_x86_64_NVIDIA).

###### eyelevel-gpu-summary

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The default configuration is sized for an NVIDIA GPU with 48 GB of GPU memory, 4 CPU cores, and at least 30 GB RAM. It deploys 2 pods (`summary.inference.replicas.desired`), which share the node's GPU. Their combined memory allocation must fit on that GPU.

For a 24 GB GPU, different worker counts or multiple nodes, follow the [summary GPU sizing notes](docs/upgrades.md#summary-gpu-sizing). The default values do not fit a 24 GB GPU. The guide includes the tested configuration, shared-storage requirements and upgrade downtime considerations.

If your machine has different resources than this, you will need to modify `summary.inference` in your `values.yaml` using the per pod requirements described above to optimize for your node resources.

Note: in many cloud Kubernetes services, such as EKS, you must use a node image that supports GPUs (e.g. AL2023_x86_64_NVIDIA).

### Configure Node Groups

As mentioned in the [node groups](#node-groups) section, node labels are defined in [values.yaml](src/groundx/values.yaml) and must be applied to appropriate nodes within your cluster. Default node label values include:

```text
eyelevel-cpu-memory
eyelevel-cpu-only
eyelevel-gpu-layout
eyelevel-gpu-ranker
eyelevel-gpu-summary
```

Different pod families can share nodes when resources permit, but a node can carry only one value for the `eyelevel_node` label. To combine families on the same nodes, configure their selectors to use the same label value. See the [total recommended resources](#total-recommended-resources) and [node group resources](#node-group-resources).

For the default full deployment, **all** required node labels must exist on **at least 1 node group** within your cluster. The label should be applied with a string key named `eyelevel_node` and an enumerated string value from the list above.

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
  -f helm/values/nvidia/values.yaml
```

#### Installing in Microsoft Azure

If you're installing the NVIDIA GPU operator into Microsoft Azure, be sure to set the `runtimeClass` to `nvidia-container-runtime`. We have included an example yaml that shows how to do this at `helm/values/nvidia/values.aks.yaml`.

If you'd like to install the NVIDIA GPU Operator with this AKS-specific yaml, use the following commands below:

```bash
helm install nvidia-gpu-operator nvidia/gpu-operator \
  -n nvidia-gpu-operator \
  --create-namespace \
  --atomic \
  -f helm/values/nvidia/values.aks.yaml
```

## Installing Services

### Redis

#### Using an Existing Redis Cluster

If you wish to use an existing redis cache, you must configure the `cache.existing` and `cache.metrics.existing` parameters in your `values.yaml`.

#### Upgrading to Chart 0.2.8 with a `rediss://` Redis

Images from chart 0.2.8 verify Redis certificates. Before upgrading a TLS-enabled Redis connection, follow the [Redis TLS upgrade notes](docs/upgrades.md#redis-tls-upgrades).

#### Deploying a Dedicated Redis Cluster

If you'd like to install redis to your cluster, instances will be automatically created during the application installation for you so long as `cache.existing` is an empty dictionary and `cache.enabled` is `true`.

### Workspace

Workspace is optional and disabled by default. See [Workspace configuration](docs/workspace.md) to enable managed code projects, publishing or managed application data.

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
  -f helm/values/percona/values.operator.yaml
helm install db-cluster \
  percona/pxc-db \
  -n eyelevel \
  -f helm/values/percona/values.cluster.yaml
```

### MinIO AIStor

GroundX stores files in one S3-compatible bucket (`file.bucketName`, default `eyelevel`). New installs use MinIO AIStor with your own license. S4 is a license-free option for small installs. Existing community MinIO tenants can [upgrade to AIStor](#upgrading-an-existing-minio-install-to-aistor) or [stay on community MinIO](#staying-on-community-minio).

#### Using an Existing MinIO Cluster

If you wish to use an existing MinIO or AIStor cluster, you must configure the `file.existing` parameters in your `values.yaml`.

#### Using AWS S3

If you wish to use an existing AWS S3 bucket, you must configure the `file.existing` parameters in your `values.yaml` **and** set `file.existing.serviceType` to `s3`.

#### Using S4

[S4](https://github.com/rh-aiservices-bu/s4) is an experimental storage option for small installations, with one replica and no high availability. Use AIStor for production.

Follow [S4 installation, configuration and limits](docs/storage/s4.md#installation). The documented installation and migration procedures assume `fileAccess.enabled: false`; do not use their anonymous-read policy with the new protected-file starter. Existing-store migration must preserve stored URLs and object keys.

#### Deploying a Dedicated AIStor Object Store

If you'd like to install MinIO AIStor to your cluster, you need an AIStor license. GroundX does not ship one. The AIStor Free license covers a single server and allows commercial use but not redistribution; a store with more than one server needs a paid license ([AIStor Free agreement](https://www.min.io/legal/aistor-free-agreement)).

These steps install the AIStor operator in namespace `aistor` and an object store named `minio-tenant` in `eyelevel`. With that name and TLS off, the store serves the hosts GroundX uses by default (`minio` and `minio-tenant-hl`), so GroundX needs no `file` settings other than the store's credentials. The chart versions are pinned to `aistor-operator` 6.0.0 and `aistor-objectstore` 1.1.0.

The commands below provision the object store. For the new protected-file starter, also complete the [private storage and HTTPS configuration](docs/agents/private-file-access.md) before installing GroundX. The TLS-off defaults below are not sufficient for that configuration.

Add the AIStor repository, store your license as Secret `minio-license` (key `minio.license`) in the operator's namespace, and install the operator:

```bash
helm repo add minio https://helm.min.io/
helm repo update

kubectl create namespace aistor
kubectl -n aistor create secret generic minio-license \
  --from-file=minio.license=<path-to-your-license-file>

helm install aistor-operator \
  minio/aistor-operator \
  --version 6.0.0 \
  -n aistor \
  -f helm/values/aistor/values.operator.yaml
```

The operator values run the operators on the `eyelevel-cpu-only` nodes and turn off the operator's cluster-wide pod webhook and its automatic certificate approval.

Choose the object store's root credentials and put them in Secret `minio-tenant-env-configuration`. The object store values read the credentials from this Secret, which keeps them out of the Helm release; the chart also refuses to create the Secret itself with the well-known pair `minio`/`minio123`.

```bash
cat > config.env <<'EOF'
export MINIO_ROOT_USER=<access-key>
export MINIO_ROOT_PASSWORD=<secret-key>
EOF
kubectl -n eyelevel create secret generic minio-tenant-env-configuration \
  --from-file=config.env
rm config.env
```

For the new starter, put these credentials in the Secret named by `fileAccess.storageCredentialsSecretName`, using keys `GROUNDX_ACCESS_KEY_ID` and `GROUNDX_SECRET_ACCESS_KEY`. Do not set inline `file.username` or `file.password` when file access is enabled. A legacy install with file access disabled can use those inline values.

Then install the object store:

```bash
helm install minio-tenant \
  minio/aistor-objectstore \
  --version 1.1.0 \
  -n eyelevel \
  -f helm/values/aistor/values.objectstore.yaml
```

Confirm that the store started with the license in place:

```bash
kubectl -n eyelevel get objectstore minio-tenant
```

The install is complete when `STATE` reads `Initialized` and `HEALTH` reads `green`. Without the `minio-license` Secret, the operator does not create the object store: no store pods or services appear, the state reports that Secret `minio-license` was not found, and GroundX keeps waiting for storage. Create the Secret in `aistor` to let the store start.

#### Object Keys That Start with a Slash

Before upgrading to chart 0.2.8, a store connected as `serviceType: minio` that preserves leading `/` keys needs a [key rename](docs/storage/minio-migration.md#object-keys-that-start-with-a-slash). MinIO, AIStor, and AWS S3 (`serviceType: s3`) are unaffected. Stop uploads and wait for processing to finish before renaming. Rolling back to 0.2.7 requires reversing the rename; new 0.2.8 objects may remain unreadable.

#### Upgrading an Existing MinIO Install to AIStor

Follow [Upgrading an Existing MinIO Install to AIStor](docs/storage/minio-migration.md#upgrading-an-existing-minio-install-to-aistor). The upgrade is permanent. Stop uploads and wait for processing to finish, then snapshot the tenant disk before uninstalling anything. Helm 3.17 or later and an AIStor license are required; multiple servers need a paid license. GroundX's EKS Terraform does not install the snapshot controller or `VolumeSnapshotClass`.

#### Restoring Community MinIO from the Pre-Upgrade Snapshot

Follow [Restoring Community MinIO](docs/storage/minio-migration.md#restoring-community-minio-from-the-pre-upgrade-snapshot). The restore deletes the current volume claim, so confirm the snapshot is ready first. It loses all objects written after the snapshot, including AIStor-era writes. GroundX's database and search index are not restored; affected documents stay listed without their files and must be re-ingested.

#### Staying on Community MinIO

Community MinIO receives no fixes. Its default server image no longer downloads anonymously, so rescheduled pods may not start. Keep the running image in your own registry and [point the tenant at that copy](docs/storage/minio-migration.md#staying-on-community-minio).

### OpenSearch

#### Using an Existing OpenSearch Cluster

If you wish to use an existing OpenSearch cluster, you must configure the `search.existing` parameters in your `values.yaml`.

#### Deploying a Dedicated OpenSearch Cluster

First follow [OpenSearch certificate and credential setup](docs/upgrades.md#installing-opensearch) to create the `opensearch-tls` and `opensearch-internal-users` Secrets from certificates you issue (node `CN=opensearch-node`, admin `CN=gx-opensearch-admin`) and add the OpenSearch CA to the `fileAccess.caSecretName` bundle. Use the same administrator password for GroundX's `search.privilegedPassword` (or `SEARCH_INIT_PASSWORD`). The seed values file holds no certificate, key or password hash; do not put any in it. Then install OpenSearch:

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update

helm install opensearch opensearch/opensearch --version 2.23.1 -n eyelevel -f helm/values/opensearch/values.yaml
```

Keep `-f helm/values/opensearch/values.yaml` on every `helm upgrade opensearch …`, followed by `opensearch-overrides.yaml` if you changed any OpenSearch setting: without it, a changed `clusterName` or `nodeGroup` starts OpenSearch on a new, empty volume (see [Upgrading existing OpenSearch](docs/upgrades.md#upgrading-existing-opensearch)). The values pin the tested OpenSearch image. To trust OpenSearch with its own CA, rotate certificates or fix a `request timed out` error, see [OpenSearch](docs/upgrades.md#opensearch). The GroundX application user has broad privileges, so also restrict network access to OpenSearch.

### Kafka

#### Using an Existing Kafka Cluster

If you wish to use an existing Kafka cluster, you must configure the `stream.existing` parameters in your `values.yaml`.

#### Using AWS SQS

If you wish to use existing AWS SQS queues, you must configure the `stream.existing` parameters in your `values.yaml` **and** set `stream.existing.serviceType` to `sqs`.

#### Deploying a Dedicated Kafka Cluster

If you'd like to install Kafka to your cluster, use the following commands below:

```bash
helm install stream-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  -n eyelevel \
  -f helm/values/strimzi/values.yaml
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

Helm reads your installation settings from a YAML file. For a new installation with ingestion and search, run this from the repository root:

```bash
cp sample.values.yaml values.yaml
```

Edit `values.yaml` with your settings before installing. Replace all placeholders and example hostnames. Keep the completed file out of source control because it contains credentials.

| Settings | What to supply |
|---|---|
| `licenseKey` | The GroundX license key for this installation. |
| `admin.apiKey`, `admin.username`, `admin.email` | A different generated UUID for each of the first two fields, plus the administrator's email. Generate both UUIDs with `bin/uuid`. |
| `cluster.type`, `cluster.pvClass`, `cluster.pvAccessMode` | Kubernetes platform, existing StorageClass and its supported access mode. Prefer `ReadWriteMany` for shared filesystems; use `ReadWriteOnce` for block/local storage. |
| `db.username`, `db.password`, `db.privilegedUsername`, `db.privilegedPassword` | MySQL application credentials and an account with permission to create and upgrade the GroundX database schema. Match the accounts configured when installing MySQL. |
| `file.bucketName`, `file.customDomain` | Object-store bucket and stable file-delivery hostname. The hostname must match `fileAccess.publicUrl`. |
| `fileAccess` | File-delivery and storage URLs, storage credentials, HTTPS certificates and ingress settings. Follow the file-access steps below. |
| `search.password`, `search.privilegedPassword` | Application and administrator passwords matching OpenSearch. Neither is required for `mode: ingest`. |
| `fileAccess.caSecretName` | When the chart deploys OpenSearch: a Secret whose `ca.crt` holds the public root CAs plus the CA that signed the OpenSearch node certificate, unless `search.caSecretName` names a Secret holding that CA. See [OpenSearch setup](docs/upgrades.md#installing-opensearch). |

Authentication uses API keys by default, without password login. See [identity modes](docs/on-prem-identity.md) to configure local password login or Amazon Cognito.

The sample enables the GroundX file gateway, which applies your file-access policies to downloads. Complete the [file-access deployment guide](docs/agents/private-file-access.md) for your storage provider before deploying. It covers URLs, DNS, ingress, certificates, credentials, compatible images and storage tests.

The sample leaves two verification flags false. Complete the guide's checks before setting them true:

1. `fileAccess.originsPrivate`: every storage address rejects unauthenticated reads, authorized processing works, and stored files and storage connections are encrypted.
2. `fileAccess.frontProxyTLSVerified`: HTTPS is configured, and traffic between your ingress or proxy and the gateway is encrypted.

Helm blocks installation until both flags are true. The flags record your verification; they do not change bucket permissions or configure encryption. Create the required Kubernetes Secrets and network routes before installing.

The chart's default for `fileAccess.enabled` remains `false`. Using your existing values file on an upgrade does not enable the gateway automatically.

For external services or specialized deployments, see the [service installation instructions](#installing-services), [connection examples](helm/values) and [full values reference](helm/README.md).

Set both OpenSearch passwords to match your installed service. [Password delivery and image compatibility](docs/upgrades.md#groundx-password-delivery) covers using Kubernetes Secrets and upgrading older images.

#### Upgrading an Existing Install

Keep your existing values file. Before upgrading, follow the [OpenSearch upgrade steps](docs/upgrades.md#upgrading-existing-opensearch) and [database migration requirements](docs/agents/database-upgrades.md). Installs from chart 0.2.9 or earlier run OpenSearch on its published demo certificates and may still use published passwords; the `groundx` and `process` images of chart 0.2.8 and later already reject the demo certificate. For OpenSearch 2.19 or later the upgrade to 3.2.0 is forward-only (OpenSearch cannot be downgraded); an older OpenSearch is re-certified without changing its version.

### Persistent Storage

Set `cluster.pvClass` to an existing StorageClass and `cluster.pvAccessMode` to a mode it supports. Prefer `ReadWriteMany` for shared filesystems; use `ReadWriteOnce` for block or local storage. Summary pods on multiple nodes need shared `ReadWriteMany` storage.

See [persistent storage configuration and upgrades](docs/upgrades.md#persistent-storage) for provider examples, EKS setup and existing StorageClass limitations. Do not change an existing StorageClass's immutable parameters during an upgrade.

### Helm Installation

When deploying from this checkout with an environment-specific values file, use the local source chart:

```bash
helm upgrade --install groundx src/groundx -n eyelevel -f values.yaml
```

Use the customized `values.yaml` from Configuration. Do not set image
tags manually for a normal release; workloads that do not override their image tag use the chart
`appVersion` from `src/groundx/Chart.yaml`.

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

For upgrades, keep your customized `values.yaml`. Do not replace it with `sample.values.yaml`.

Before upgrading, follow the [database upgrade requirements](docs/agents/database-upgrades.md) and the [OpenSearch credential steps](#upgrading-an-existing-install). Then pass your existing file to Helm:

```bash
helm upgrade groundx groundx/groundx -n eyelevel -f values.yaml
```

To enable the file gateway on an existing installation, follow the [existing-file activation procedure](docs/agents/private-file-access.md#upgrade-existing-files-before-activation). It includes preparing older files, selecting compatible images and testing your storage provider.

# Autoscaling & Monitoring

GroundX includes built-in **Horizontal Pod Autoscaling (HPA)** and an optional **custom metrics server**.

Autoscaling is workload-aware: pods scale on **pipeline throughput** plus one additional metric (latency/backlog/throughput) depending on pod type.

## Enabling Autoscaling (HPA)

HPA can be globally enabled for all supported pods:

```yaml
cluster:
  hpa: true
```

If `cluster.hpa` is `false`, pods run with fixed replica counts.

### Per-Pod HPA Control

You can enable or disable HPA per pod:

```yaml
groundx:
  replicas:
    hpa: true
```

If HPA is **disabled** for a pod:

```yaml
POD.replicas.desired
```

controls the replica count.

If HPA is **enabled** for a pod:

```yaml
POD.replicas.min
POD.replicas.max
```

control the scaling bounds.

## How Autoscaling Works

Every autoscaled pod scales on **two metrics**:

1. **Pipeline throughput (all pods)**
   - The system estimates total pipeline throughput for files moving through GroundX.
   - Each pod defines the throughput a single replica can support.
   - Replicas increase until total pod capacity meets the estimated pipeline throughput.

2. **Pod-specific metric (by pod type)**
   - **api**: response latency (default target **4s**)
   - **queue**: message backlog (default target **10**)
   - **task**: Celery task backlog (default target **10**)
   - **inference**: model request throughput (scales when requests exceed per-replica capacity)

For GPU inference, HPA scale-up also depends on node readiness. If each inference
pod uses a full GPU node, every additional replica needs both a new pod and a new
GPU node before it can absorb traffic.

## Enabling the Custom Metrics Server

The custom metrics server exposes:
- Pipeline throughput
- API latency
- Queue backlog
- Task backlog
- Inference request throughput

Enable it with:

```yaml
metrics:
  enabled: true
```

## Prometheus Integration (Optional)

If using Prometheus Operator, enable the ServiceMonitor:

```yaml
metrics:
  serviceMonitor:
    enabled: true
```

This allows Prometheus to automatically scrape the GroundX metrics endpoints.

For detailed monitoring setup, see the dedicated [Monitoring README](monitoring/README.md).

## Using Simulated LLM Responses (Optional)

To run the system without calling OpenAI or self-hosted LLMs (useful for load testing or autoscaling validation), configure:

```yaml
engines:
  default:
    engineId: test-model

extract:
  agent:
    modelId: test-model
```

When set, pods use simulated LLM responses instead of external model providers.

## Terminal Extract Diagnostics

Terminal diagnostics are disabled by default. See [extract diagnostics](docs/extract-diagnostics.md) for compatible images, shared and per-pod settings, and rollout requirements.

# Using GroundX On-Prem

## Get the API Endpoint

Once the setup is complete, run:

```bash
kubectl -n eyelevel rollout status deployment/groundx
kubectl -n eyelevel get svc groundx
```

The API endpoint will be the external IP associated with the GroundX load balancer.

For instance, the "external IP" might resemble the following:

```bash
EXTERNAL-IP
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxx.us-east-2.elb.amazonaws.com
```

## Use the SDKs

The [API endpoint](#get-the-api-endpoint), in conjunction with the `admin.apiKey` defined during deployment, can be used to configure the GroundX SDK to communicate with your On-Prem instance of GroundX.

Configure HTTPS at your API ingress or proxy before sending API keys. The examples below assume that HTTPS endpoint is ready.

Note: you must append `/api` to your [API endpoint](#get-the-api-endpoint) in the SDK configuration.

```python
from groundx import GroundX

external_ip = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxx.us-east-2.elb.amazonaws.com'
api_key="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

client = GroundX(api_key=api_key, base_url=f"https://{external_ip}/api")
```

```typescript
import { GroundXClient } from "groundx";

const external_ip = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxxxx.us-east-2.elb.amazonaws.com'

const groundx = new GroundXClient({
  apiKey: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  environment: `https://${external_ip}/api`,
});
```

## Use the APIs

The [API endpoint](#get-the-api-endpoint), in conjunction with the `admin.apiKey` defined during deployment, can be used to interact with your On-Prem instance of GroundX.

All of the methods and operations described in the [GroundX documentation](https://documentation.groundx.ai/reference) are supported with your On-Prem instance of GroundX. You simply have to substitute `https://api.groundx.ai` with your [API endpoint](#get-the-api-endpoint).

# Terraform Deployment (terraform/aws/)

`terraform/aws/` is an optional path for creating AWS infrastructure before the Helm installation. It also remains supported for maintaining infrastructure it provisioned. GroundX itself is installed with Helm.

See [AWS infrastructure with Terraform](terraform/aws/README.md) for EKS versions, upgrade precautions, cost controls and node diagnostics.

## Accessing Legacy Scripts

Legacy application deployment scripts are linked from the [Terraform guide](terraform/aws/README.md#accessing-legacy-scripts).

## EKS CPU and monitoring cost controls

See [EKS cost controls](docs/agents/eks-cost-controls.md).

## Optional EKS Node Diagnostics

See [EKS Node Diagnostics](docs/eks-node-diagnostics.md).

## EKS Cluster Version Configuration

See [EKS version configuration and upgrade precautions](terraform/aws/README.md#eks-cluster-version-configuration).

## Reference Guides

- [Identity and login modes](docs/on-prem-identity.md)
- [Private file access](docs/agents/private-file-access.md)
- [Deployment and upgrade notes](docs/upgrades.md)
- [Workspace](docs/workspace.md)
- [Large-file delivery](docs/agents/large-file-delivery.md) and [post-processing](docs/agents/post-processing.md)
- [Monitoring](monitoring/README.md) and [extract diagnostics](docs/extract-diagnostics.md)
- [Full values reference](helm/README.md) and [configuration examples](helm/values)
- [Contributing](CONTRIBUTING.md)
