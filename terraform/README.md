# Azure Terraform Infrastructure

This directory provisions the Inventory Manager infrastructure on Microsoft Azure.
The application VM and PostgreSQL server use private networking; Azure Bastion
provides SSH access without assigning a public IP to the VM.

## Resources

- Resource group and virtual network.
- `AzureBastionSubnet` with an Azure Bastion host and static public IP.
- Private application subnet with an NSG, NAT Gateway, and an Ubuntu VM.
- Private GitHub Actions runner VM subnet with Bastion-only SSH access and NAT
  for outbound runner traffic.
- Private endpoint subnet, Premium Azure Container Registry with public access
  disabled, Private Link DNS shared across the VNet, and an NSG that allows
  registry HTTPS only from the application and runner subnets.
- Delegated PostgreSQL subnet, private DNS zone, and private Azure Database for
  PostgreSQL Flexible Server.
- The application VM's managed identity receives registry-scoped `AcrPull`
  and `Reader`; the runner VM receives `AcrPush` and `Reader`.

The application stores inventory in PostgreSQL. The VM's systemd service uses
its managed identity to pull the `inventory-manager` image from ACR and connects
to PostgreSQL using a separate application login. The VM waits and retries while
the image is not yet available in ACR.

The private runner publishes the exact image artifact that CI scanned. It is
intentionally not registered as a GitHub runner by cloud-init: registration
requires a short-lived token and must be completed manually after deployment.
Restrict the organization runner group to this repository and the trusted
`cd.yml` workflow on `main` before enabling CD.

## Prerequisites

- Terraform 1.5 or later.
- Azure CLI, signed in to a subscription with permission to create the resources
  and assign the `AcrPull`, `AcrPush`, and `Reader` roles.
- An SSH key pair.
- Unique Azure names for the PostgreSQL server and container registry.
- A GitHub organization runner group named `private-acr`, restricted to the CD
  workflow. This is a manual GitHub administration step.

Premium ACR, Private Link, Bastion, NAT Gateway, PostgreSQL, and both VMs incur
ongoing charges. Check current regional pricing, student-credit eligibility,
quotas, and VM SKU availability before deployment. No Terraform apply is
authorized by this documentation.

## Configure

From the repository root:

```powershell
az login
az account set --subscription "<YOUR_AZURE_SUBSCRIPTION_ID>"
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` with your subscription ID, SSH public key,
unique resource names, and strong, distinct PostgreSQL administrator and
application passwords. Do not commit this file, private keys, Terraform state
files, or saved plans. Terraform state and VM cloud-init data contain encoded
database credentials; base64 is not encryption. Restrict access to both and use
a secured remote state backend for shared deployments.

## Initialize and validate

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
```

## Plan and deploy

Review the full plan before applying it:

```powershell
terraform -chdir=terraform plan -out=tfplan
terraform -chdir=terraform apply tfplan
```

The application VM has no public IP. Connect using Azure Bastion and the VM's
private address from `terraform output application_private_ip_address`.
`terraform output bastion_public_ip_address` shows the Bastion public IP.
PostgreSQL is private-only; its hostname is available from
`terraform output postgresql_fqdn`. The registry login server is available from
`terraform output container_registry_login_server`.

The Terraform configuration provisions a Standard public load balancer that
forwards HTTP port 80 to the application on port 3000 and probes `/health`.
Its public IP and URL are available through the `application_public_ip_address`
and `application_public_url` outputs after creation. The listener is plain
HTTP, not HTTPS. Terraform configuration is not proof of deployed Azure
resources; the currently checked Azure for Students subscription was empty.
Do not present any URL or resource as live without separately verifying it.

Read-only mode is enabled by the cloud-init service using
`INVENTORY_READ_ONLY=true`. Terraform ignores changes to VM `custom_data` to
avoid replacing an existing VM, so this setting in cloud-init only applies
when a VM is initially provisioned. Existing guest configuration must be
updated through an approved deployment or direct VM operation.

The VM uses its managed identity to pull the image. No registry admin password
is enabled or needed. CI builds and scans the image, stores it as a
one-day Actions artifact, and the private runner pushes that same artifact
using its managed identity. The local Compose stack can exercise the database
integration using PostgreSQL in Docker; see the repository README.

GitHub Actions CD publishes and deploys the current commit SHA. The workflow
does not use `latest` as the deployment identity, and a Git SHA tag is not
automatically immutable; ACR tag immutability requires separate configuration.

The Terraform code configures Standard Bastion with native client tunnelling.
Whether that configuration or any other resource exists in Azure must be
verified in the target subscription; no apply is described as completed here.

### Register the private runner after an approved apply

1. Verify the runner VM is ready through Bastion and install the current
   supported GitHub Actions runner package from the repository's organization
   runner settings page. Do not copy a registration token into Terraform,
   cloud-init, a repository file, or this guide.
2. Download the current supported runner package into
   `/home/ghrunner/actions-runner`. Register it with the organization runner
   group `private-acr` and label it `private-acr`. As `ghrunner`, use the
   short-lived token shown by GitHub:

   ```bash
   cd /home/ghrunner/actions-runner
   ./config.sh \
     --url https://github.com/Kaerica/Project-foundation-and-secure-collaboration \
     --token "<SHORT_LIVED_GITHUB_RUNNER_TOKEN>" \
     --name inventory-private-acr \
     --runnergroup private-acr \
     --labels private-acr \
     --unattended
   ```

   Then install and start the runner service with an administrator account:

   ```bash
   sudo /home/ghrunner/actions-runner/svc.sh install ghrunner
   sudo /home/ghrunner/actions-runner/svc.sh start
   ```

   Never paste the registration token into a repository file or Terraform
   input.
3. In Organization Settings → Actions → Runner groups, allow only this
   repository and restrict workflow access to
   `Kaerica/Project-foundation-and-secure-collaboration/.github/workflows/cd.yml@refs/heads/main`.
   Do not allow pull-request workflows to use this runner.
4. Configure the `production` environment secrets documented in
   `ansible/README.md`. Add `AZURE_SUBSCRIPTION_ID` for the runner's Azure CLI
   context. Confirm `ACR_NAME` and resource group match Terraform outputs.
5. After runner registration, use **Re-run all jobs** on a trusted failed CD
   workflow if the original main-branch run arrived before the runner was
   online. This regenerates the one-day CI image artifact.

Both system-assigned identities are limited to the registry. The app and
runner must resolve the ACR login hostname to a private address; the workflow
refuses to push if DNS resolves publicly or ACR public access is enabled.

## Destroy

When the environment is no longer needed, review the impact and destroy the
resources to stop ongoing charges:

```powershell
terraform -chdir=terraform destroy
```
