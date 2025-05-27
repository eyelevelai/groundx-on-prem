# GroundX On-Prem/On-Cloud Kubernetes Infrastructure As Code

## Table of Contents

**[What is GroundX On-Prem?](#what-is-groundx-on-prem)**
- [GroundX Ingest Service](#groundx-ingest-service)
- [GroundX Search Service](#groundx-search-service)

**[Quick Start](#dependencies)**
- [Dependencies](#dependencies)
- [Deploy to an Existing Kubernetes Cluster](#deploy-to-an-existing-kubernetes-cluster)
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
  - [Create env.tfvars File](#create-envtfvars-file)
  - [Deploy GroundX On-Prem to Your Kubernetes Cluster](#deploy-groundx-on-prem-to-your-kubernetes-cluster)
- [Create and Deploy to a New Amazon EKS Cluster](#create-and-deploy-to-a-new-amazon-eks-cluster)
  - [Create the VPC and EKS Cluster](#create-the-vpc-and-eks-cluster)
  - [Deploy GroundX On-Prem to the New Amazon EKS Cluster](#deploy-groundx-on-prem-to-the-new-amazon-eks-cluster)
  - [A Note on Cost](#a-note-on-cost)

**[Using GroundX On-Prem](#using-groundx-on-prem)**
- [Get the API Endpoint](#get-the-api-endpoint)
- [Use the SDKs](#use-the-sdks)
- [Use the APIs](#use-the-apis)

**[Tearing Down](#tearing-down)**

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

# Quick Start

## Dependencies

GroundX On-Prem requires Kubernetes cluster `v1.18+`.

Please ensure you also have the following software tools installed before proceeding:

- `bash` shell (version 4.0 or later recommended. AWS Cloud Shell has insufficient resources.)
- `terraform` ([Setup Docs](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli))
- `kubectl` ([Setup Docs](https://kubernetes.io/docs/tasks/tools/))

If you will be using the Terraform scripts to set up infrastructure in AWS, you will also need:

- `AWS CLI` ([Setup Docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))

## Deploy to an Existing Kubernetes Cluster

If you do not have an existing Kubernetes cluster and would like to use our Terraform scripts to set up an Amazon EKS cluster, you should follow the new Amazon EKS cluster [Quick Start guide](#create-and-deploy-to-a-new-amazon-eks-cluster).

In order to deploy GroundX On-Prem to your Kubernetes cluster, you must:

1. [Check](#required-compute-resources) that you have the required compute resources
2. [Configure or create](#configure-node-groups) appropriate node groups and nodes
3. [Update](#create-envtfvars-file) `operator/env.tfvars` with your cluster information
4. [Run](#deploy-groundx-on-prem-to-your-kubernetes-cluster) the deploy script

### Background

#### Node Groups

The GroundX On-Prem pods deploy to nodes using node selector labels and tolerations. Here is [an example](modules/groundx/helm_chart/templates/deployment.yaml) from one of the k8 yaml configs:

```yaml
nodeSelector:
  node: "{{ .Values.nodeSelector.node }}"
tolerations:
  - key: "node"
    value: "{{ .Values.nodeSelector.node }}"
    effect: "NoSchedule"
```

Node labels are defined in [shared/variables.tf](shared/variables.tf) and must be applied to appropriate nodes within your cluster. Default node label values are:

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

As part of the deployment, unless otherwise specified, the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator) is installed. If you already have this operator installed in your cluster, set `cluster.has_nvidia` to `true` in your `operator/env.tfvars` config file.

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
    35 GB     disk drive space
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

The resource requirements for these pods are described detail in [operator/variables.tf](operator/variables.tf) and the [Total Recommended Resources](#total-recommended-resources) section above.

###### eyelevel-cpu-memory

Pods in this node group have a range of requirements on CPU, RAM, and disk drive space but can typically run on most machines with the [supported architecture](#chip-architecture).

CPU and memory intensive ingestion pipeline pods, such as `layout_ocr`, `layout_save`, and `pre_process`, will deploy to the **eyelevel-cpu-memory** nodes. The `layout_ocr` pod includes tesseract, which benefits from access to multiple vCPU cores.

The resource requirements for these pods are described detail in [operator/variables.tf](operator/variables.tf) and the [Total Recommended Resources](#total-recommended-resources) section above.

###### eyelevel-gpu-layout

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in [operator/variables.tf](operator/variables.tf) and the [Total Recommended Resources](#total-recommended-resources) section above.

The current configuration for this service assumes an NVIDIA GPU with 16 GB of GPU memory, 4 CPU cores, and at least 12 GB RAM. It deploys 1 pod with 6 workers on this node (called `workers` in `operator/variables.tf`) and claims the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator).

If your machine has different resources than this, you will need to modify `layout_resources.inference` in your `operator/env.tfvars` using the per pod requirements described above to optimize for your node resources.

###### eyelevel-gpu-ranker

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in [operator/variables.tf](operator/variables.tf) and the [Total Recommended Resources](#total-recommended-resources) section above.

The current configuration for this service assumes an NVIDIA GPU with 16 GB of GPU memory, 4 CPU cores, and at least 30 GB RAM. It deploys 1 pod with 14 workers on this node (called `workers` in `operator/variables.tf`). It does not claim the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator) but uses 16 GB of GPU memory.

If your machine has different resources than this, you will need to modify `ranker_resources.inference` in your `operator/env.tfvars` using the per pod requirements described above to optimize for your node resources.

###### eyelevel-gpu-summary

Pods in this node group have specific requirements on GPU, CPU, RAM, and disk drive space.

The resource requirements for these pods are described detail in [operator/variables.tf](operator/variables.tf) and the [Total Recommended Resources](#total-recommended-resources) section above.

The current configuration for this service assumes an NVIDIA GPU with 48 GB of GPU memory, 4 CPU cores, and at least 30 GB RAM. It deploys 2 pods on this node (called `workers` in `operator/variables.tf`). It does not claim the GPU via the `nvidia.com/gpu` resource provided by the [NVIDIA GPU operator](https://github.com/NVIDIA/gpu-operator) but uses 24 GB of GPU memory per worker.

If your machine has different resources than this, you will need to modify `summary_resources.inference` in your `operator/env.tfvars` using the per pod requirements described above to optimize for your node resources.

### Configure Node Groups

As mentioned in the [node groups](#node-groups) section, node labels are defined in [shared/variables.tf](shared/variables.tf) and must be applied to appropriate nodes within your cluster. Default node label values include:

```text
eyelevel-cpu-memory
eyelevel-cpu-only
eyelevel-gpu-layout
eyelevel-gpu-ranker
eyelevel-gpu-summary
```

Multiple node labels can be applied to the same node group, so long as resources are available as described in the [total recommended resource](#total-recommended-resources) and [node group resources](#node-group-resources) sections.

However, **all** node labels must exist on **at least 1 node group** within your cluster. The label should be applied with a string key named `node` and an enumerated string value from the list above.

### Create env.tfvars File

1. Create `operator/env.tfvars` file by copying the example file

```bash
cp operator/env.tfvars.example operator/env.tfvars
```

`env.tfvars` is the configuration file Terraform will use when setting up GroundX On-Prem.

2. Add admin credentials

For security reasons, you **MUST** modify the following:

- `admin.api_key`: Set this to a random UUID. You can generate one by running `bin/uuid`. This will be the API key associated with the admin account and will be used for inter-service communications.
- `admin.username`: Set this to a random UUID. You can generate one by running `bin/uuid`. This will be the user ID associated with the admin account and will be used for inter-service communications.
- `admin.email`: Set this to the email address you want associated with the admin account.

3. (Optional) Update passwords and pod resource configurations

Service usernames and passwords can be set in the other variables copied over from `operator/env.tfvars.example` (e.g. MySQL passwords).

If you need to make changes, as described in the [node group resouces](#node-group-resources) section, you will also add these to your `operator/env.tfvars` file.

4. (Optional) Update kubeconfig path

The setup scripts assume your kubeconfig file can be found at `~/.kube/config`. If that is not the case, you will need to modify `cluster.kube_config_path` in your `operator/env.tfvars` file.

### Deploy GroundX On-Prem to Your Kubernetes Cluster

Once `env.tfvars` has been properly configured, run:

```bash
operator/setup
```

This will create a new namespace and deploy GroundX On-Prem into the Kubernetes cluster.

## Create and Deploy to a New Amazon EKS Cluster

If you already have a Kubernetes cluster, including an existing AWS EKS cluster, you should follow the existing Kubernetes cluster [Quick Start guide](#deploy-to-an-existing-kubernetes-cluster).

### Create the VPC and EKS Cluster

1. Run the following command from the base directory:

```bash
environment/aws/setup-eks
```

You will be prompted for an AWS region to set up your cluster, and will also be asked to double check that you're happy with the state of the configuration file.

Once this command has executed, a VPC and Kubernetes cluster will be setup. You can proceed to deploying GroundX.

### Deploy GroundX On-Prem to the New Amazon EKS Cluster

1. Create env.tfvars file

```bash
cp operator/env.tfvars.example operator/env.tfvars
```

This creates a Terraform configuration file for the GroundX application, similar to what was described in the previous section. Now, however, some configuration is required.

2. Add admin credentials

For security reasons, you **MUST** modify the following:

- `admin.api_key`: Set this to a random UUID. You can generate one by running `bin/uuid`. This will be the API key associated with the admin account and will be used for inter-service communications.
- `admin.username`: Set this to a random UUID. You can generate one by running `bin/uuid`. This will be the user ID associated with the admin account and will be used for inter-service communications.
- `admin.email`: Set this to the email address you want associated with the admin account.

3. Once `env.tfvars` has been properly configured, run:

```bash
operator/setup
```

This will create a new namespace and deploy GroundX On-Prem into the Kubernetes cluster.

### A Note on Cost

The resources being created will incur cost via AWS. It is recommended to follow all instructions accurately and completely. So that setup and taredown are both executed completely. Experience with AWS is recommended.

### AWS EC2 Resources

The default resource configurations for AWS EC2 are specified [here](#total-recommended-resources), consisting of:

```text
1x m6a.xlarge
4x t3a.medium
1x g4dn.xlarge
1x g4dn.2xlarge
1x g6e.xlarge
~300 GB gp2
```

You may need to request a quota increase for your account for the following resources:

- Sufficient vCPUs
- GPU instances (e.g. g6e.xlarge)

# Using GroundX On-Prem

## Get the API Endpoint

Once the setup is complete, run:

```bash
kubectl -n eyelevel get svc
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

# Tearing Down

After all resources have been created, tear down can be done with the following commands.

To tear down the GroundX On-Prem deployment, run the following commands in order:

```bash
bin/operator app -c
bin/operator services -c
bin/operator init -c
```

If you used our Terraform scripts to set up an Amazon EKS cluster, run the following commands in order:

```bash
bin/environment eks -c
bin/environment aws-vpc -c
```

It is vital to run these commands in order, and it is recommended to run them one at a time manually. We have observed inconsistency and race conditions when these are run automatically.
