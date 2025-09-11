# Table of Contents

- [Table of Contents](#table-of-contents)
  - [bin/environment](#binenvironment)
    - [Usage](#usage)
    - [Components](#components)
    - [Options](#options)
    - [Examples](#examples)
  - [bin/operator](#binoperator)
    - [Usage](#usage-1)
    - [Functional Groups](#functional-groups)
    - [App Pods](#app-pods)
    - [Init Configurations](#init-configurations)
    - [Services](#services)
    - [Options](#options-1)
    - [Examples](#examples-1)
    - [Customization](#customization)
  - [Troubleshooting](#troubleshooting)

The following sections describe the function of a variety of tools and tips which can be used to manage resources within GroundX On-Prem.

## bin/environment

`bin/environment` is a script that helps you set up a VPC and Kubernetes cluster. Hosting environments that the script currently supports can be found below.

### Usage

```bash
bin/environment [component] [options]
```

Component is the cloud environment or Kubernetes cluster configuration you wish to manage.

### Components

- `aws-vpc`
  - This will create a VPC and subnets for an EKS cluster
  - The resulting VPC ID and subnet IDs are required parameters for EKS cluster setup
- `eks`
  - This will set up a new EKS cluster
  - You must configure the `environment` parameters in env.tfvars, including VPC and subnet IDs

### Options

- `-c`: Clear (destroy) mode. Reverses the order of operations and destroys instead of deploys.
- `-t`: Test mode. Skips the Terraform apply/destroy step, useful for dry runs.

### Examples

1. Create a new VPC for EKS cluster setup:

   ```bash
   bin/environment aws-vpc
   ```

2. Create a new EKS cluster:

   ```bash
   bin/environment eks
   ```

3. Destroy the EKS cluster:

   ```bash
   bin/operator eks -c
   ```

4. Test deployment of the EKS cluster without making any changes to the AWS account:

   ```bash
   bin/operator eks -t
   ```

## bin/operator

Deployments are managed using the `bin/operator` script found in the root of this repository.

### Usage

```bash
bin/operator [component] [options]
```

Component is the service, pod, configuration, or functional group you wish to manage.

### Functional Groups

- `init`
- `services`
- `app`

### App Pods

- `groundx`
- `layout-webhook`
- `pre-process`
- `process`
- `queue`
- `summary-client`
- `upload`
- `ranker`
- `layout`
- `summary`

### Init Configurations

- `add`
- `config`

### Services

- `cache`
- `db`
- `file`
- `search`
- `stream`

### Options

- `-c`: Clear (destroy) mode. Reverses the order of operations and destroys instead of deploys.
- `-t`: Test mode. Skips the Terraform apply/destroy step, useful for dry runs.

### Examples

1. Deploy all components:

   ```bash
   bin/operator
   ```

2. Deploy a specific group:

   ```bash
   bin/operator services
   ```

3. Deploy a specific app:

   ```bash
   bin/operator groundx
   ```

4. Destroy a specific service:

   ```bash
   bin/operator db -c
   ```

5. Test deployment of an init task:

   ```bash
   bin/operator add -t
   ```

### Customization

To add new components or modify existing ones, update the following arrays in the script:

- `valid_groups`
- `recursive_types`
- `valid_apps`
- `valid_init`
- `valid_services`

Ensure that the directory structure under the `operator/` folder matches these configurations.

## Troubleshooting

1. **"Unknown request type" error**: Check if the component you're trying to deploy/destroy is listed in the appropriate array in the script.

2. **"Directory does not exist" error**: Ensure that the directory structure under `operator/` or  `environment/` matches the components defined in the script.

3. **Terraform errors**: Check your Terraform configurations and AWS credentials if you encounter Terraform-specific errors.

4. **Permission issues**: Ensure the script has execute permissions (`chmod +x script_name`).

For any other issues, check the Terraform output for specific error messages and consult the Terraform documentation.
