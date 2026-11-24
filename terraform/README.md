# Azure Terraform Infrastructure

This directory provisions the Inventory Manager infrastructure on Microsoft Azure.
The application VM and PostgreSQL server use private networking; Azure Bastion
provides SSH access without assigning a public IP to the VM.

## Resources

- Resource group and virtual network.
- `AzureBastionSubnet` with an Azure Bastion host and static public IP.
- Private application subnet with an NSG, NAT Gateway, Ubuntu VM, and a public
  Standard Load Balancer that forwards HTTP port 80 to the VM's port 3000.
- Delegated PostgreSQL subnet, private DNS zone, and private Azure Database for
  PostgreSQL Flexible Server.
- Basic Azure Container Registry with its admin account disabled. The VM's
  managed identity receives the `AcrPull` role. This tier uses a public
  registry endpoint and does **not** satisfy a private-registry requirement.

The application stores inventory in PostgreSQL. The VM's systemd service uses
its managed identity to pull the `inventory-manager` image from ACR and connects
to PostgreSQL using a separate application login. The VM waits and retries while
the image is not yet available in ACR.

## Prerequisites

- Terraform 1.5 or later.
- Azure CLI, signed in to a subscription with permission to create the resources
  and assign the `AcrPull` role.
- An SSH key pair.
- Unique Azure names for the PostgreSQL server and container registry.

Azure Bastion, NAT Gateway, PostgreSQL, and the VM incur ongoing charges. Check
current regional pricing and quotas before deployment. The public Load
Balancer and static IP may also incur charges.

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
`terraform output container_registry_login_server`. Terraform also outputs
`application_public_url`, which is the public HTTP endpoint through the Load
Balancer.

After cloud-init completes, connect to the VM through Bastion and verify the
systemd service and database-backed health endpoint:

```bash
sudo systemctl is-active inventory-manager.service
curl --fail --show-error http://127.0.0.1:3000/health
```

The health request should return `{"status":"ok"}`. Run it on the VM because no
public DNS name or HTTPS certificate is configured. The Load Balancer's health
probe checks the same endpoint.

After the backend is healthy and cloud-init has completed, verify the public
HTTP endpoint from a client outside the VNet:

```powershell
$applicationUrl = terraform -chdir=terraform output -raw application_public_url
Invoke-RestMethod "$applicationUrl/health"
Invoke-RestMethod "$applicationUrl/"
```

The health endpoint must return `{"status":"ok"}` and the root endpoint must
return a JSON product list. The cloud VM runs with
`INVENTORY_READ_ONLY=true`: public product listing and health checks are
available, but `POST /products` and `PATCH /products/:id/quantity` return HTTP
403. HTTP is unencrypted; use only non-sensitive demonstration data and do not
send credentials or private information to this endpoint.

Build and push the application image after the registry is created. The VM
service retries the pull until this image is available:

```powershell
$registryName = terraform -chdir=terraform output -raw container_registry_name
$registryServer = terraform -chdir=terraform output -raw container_registry_login_server
$image = "${registryServer}/inventory-manager:latest"
docker build -t $image .
az acr login --name $registryName
docker push $image
```

The VM uses its managed identity to pull the image. No registry admin password
is enabled or needed. The local Compose stack can exercise the same database
integration using PostgreSQL in Docker; see the repository README.

The proposed GitHub Actions CD workflow is in open PR #37, not in the current
main branch. It requires Azure Bastion native-client tunneling, which the
current Basic Bastion SKU does not support. CD cannot be verified until an
approved Standard/Premium Bastion or an in-VNet runner is available and the
workflow is merged and configured.

### Private registry limitation

This student/development configuration currently uses Basic ACR with public
network access enabled. It is not a private registry. Azure Private Link for
ACR requires the Premium tier, adds recurring cost, and requires image pushes
from a client with private network access (or an approved private build
runner). Do not treat the current `docker push` instructions as a private
registry workflow. The Premium/Private Link design and publishing path require
team approval before changing this configuration.

## Destroy

When the environment is no longer needed, review the impact and destroy the
resources to stop ongoing charges:

```powershell
terraform -chdir=terraform destroy
```
