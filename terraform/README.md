# Azure Terraform Infrastructure

This directory provisions the Inventory Manager infrastructure on Microsoft Azure.

## Prerequisites

Install Terraform and Azure CLI, and have an Azure subscription and SSH key pair available.

Verify the installations:

```powershell
terraform version
az version
```

## Azure login

```powershell
az login
az account set --subscription "<YOUR_AZURE_SUBSCRIPTION_ID>"
az account show --output table
```

## Configure variables

Copy the example variables file:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set the subscription ID, region, environment, VM size,
administrator username, SSH public key, and allowed SSH CIDR.

Do not commit `terraform.tfvars`, private SSH keys, Terraform state files, or saved plans.

## Initialize Terraform

From the repository root:

```powershell
terraform -chdir=terraform init
```

## Format and validate

```powershell
terraform -chdir=terraform fmt
terraform -chdir=terraform validate
```

## Review the deployment plan

```powershell
terraform -chdir=terraform plan -out=tfplan
```

Review the plan before applying it.

## Deploy

```powershell
terraform -chdir=terraform apply tfplan
```

View deployment outputs:

```powershell
terraform -chdir=terraform output
```

Test the application health endpoint:

```text
http://<PUBLIC_IP>:3000/health
```

The expected response is:

```json
{"status":"ok"}
```

## Destroy the infrastructure

When the environment is no longer needed:

```powershell
terraform -chdir=terraform destroy
```

Enter `yes` when prompted. This removes the Azure resources and prevents further charges.