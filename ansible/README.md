# Ansible deployment

Ansible deploys the Inventory Manager to the private Azure application VM. It
does not create infrastructure or replace the VM's PostgreSQL configuration.
The VM is reached through Azure Bastion using a local SSH tunnel; its public
address is not used.

## Deployment model

Terraform creates the VM with:

- a system-assigned managed identity,
- AcrPull permission on Azure Container Registry,
- a systemd service named `inventory-manager`,
- PostgreSQL connection settings, and
- an initial container image from ACR.

The systemd service starts `/usr/local/sbin/start-inventory-manager`. The
script reads `/etc/inventory-manager.env`, authenticates with ACR using the VM
managed identity, pulls the configured image, and runs the application on port
3000. That identity has registry-scoped `AcrPull` and `Reader` roles so Azure
CLI can resolve registry metadata and authenticate without an admin password.

The Ansible playbook installs Docker and Compose, updates the image/tag
environment file, and restarts the systemd service when the requested image ID
or deployment environment changes. After the health check, it verifies that
the running container's image ID matches the requested image. This catches a
startup wrapper that ignores the updated tag instead of reporting a false
deployment success. Rerunning the same image tag is idempotent and does not
restart the application when the image and environment are unchanged.

## Bastion tunnel

Run the following commands from the repository root. Supply the current
Terraform resource names and VM resource ID.

```bash
az network bastion tunnel \
  --name "<BASTION_NAME>" \
  --resource-group "<RESOURCE_GROUP>" \
  --target-resource-id "<VM_RESOURCE_ID>" \
  --resource-port 22 \
  --port 2222
```

In another terminal, validate the inventory and SSH connection:

```bash
export ANSIBLE_CONFIG="$PWD/ansible/ansible.cfg"
ansible-playbook -i ansible/inventory.ini --syntax-check ansible/playbook.yml
ansible inventory -i ansible/inventory.ini \
  -m ansible.builtin.ping \
  -e ansible_ssh_private_key_file="$HOME/.ssh/ansible_cd"
```

Set `ansible_user` to the Terraform `admin_username` and keep the SSH private
key outside the repository. If the tunnel uses a different local port, pass
`-e ansible_port=<PORT>`.
The syntax check also runs in Ubuntu CI and does not connect to or change the
live VM.

## Manual deployment

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
  -e ansible_host=127.0.0.1 \
  -e ansible_port=2222 \
  -e ansible_ssh_private_key_file="$HOME/.ssh/ansible_cd" \
  -e ansible_user="<TERRAFORM_VM_ADMIN_USERNAME>" \
  -e container_registry_name="<ACR_NAME>" \
  -e container_registry_resource_group="<AZURE_RESOURCE_GROUP>" \
  -e container_registry_login_server="<ACTUAL_ACR_LOGIN_SERVER>" \
  -e azure_subscription_id="<AZURE_SUBSCRIPTION_ID>" \
  -e container_image_tag="<GIT_SHA_OR_COMMIT_TAG>"
```

Use `terraform output -raw container_registry_login_server` when available
instead of constructing an ACR hostname. The login server is passed directly to
Ansible and must match the registry used to publish the image.

## Verification

From an SSH session to the application VM:

```bash
curl --fail http://127.0.0.1:3000/health
docker ps --filter name=inventory-manager
sudo systemctl status inventory-manager --no-pager
sudo journalctl -u inventory-manager --no-pager -n 100
```

The health response must be `{"status":"ok"}`. The VM does not have a public IP,
so use Azure Bastion or another host inside the VNet for external application
connectivity tests.

## Continuous Deployment

[`.github/workflows/cd.yml`](../.github/workflows/cd.yml) runs after a merge to
`main`, and calls the same CI workflow first. Deployment only starts if CI
passes. It:
1. calls the shared CI workflow, which tests and scans the image,
2. validates production secrets, ACR settings, Bastion, and the target VM on a
   hosted preflight runner,
3. passes the scanned image artifact to the private VNet runner,
4. uses the runner's managed identity to push the Git-SHA-tagged image to
   Premium ACR over Private Link,
5. opens an Azure Bastion tunnel from a hosted runner,
6. runs this playbook through Ansible,
7. verifies `/health` and the running image ID, and
8. closes the tunnel.

The Git SHA tag identifies the exact commit used to build an image. It is not
automatically immutable: registry-level tag immutability must be enabled and
configured separately in Azure Container Registry.

Terraform configures Standard Bastion and native client tunnelling, but the
configuration is not proof that resources exist. Standard Bastion may add
ongoing cost. The end-to-end GitHub deployment has not been verified.

The image ID check intentionally fails if the running service does not match
the requested tag. The existing production VM's startup wrapper must consume
`/etc/inventory-manager.env`; this repository change cannot update or verify
that VM without a deployment run.

Configure these GitHub Actions secrets for the `production` environment:

| Secret | Purpose |
| --- | --- |
| `AZURE_CREDENTIALS` | Azure service principal JSON for login |
| `AZURE_RESOURCE_GROUP` | Terraform resource group |
| `AZURE_BASTION_NAME` | Azure Bastion resource name |
| `AZURE_VM_RESOURCE_ID` | Full resource ID of the application VM |
| `AZURE_VM_ADMIN_USERNAME` | VM administrator username |
| `AZURE_VM_SSH_PRIVATE_KEY` | Private key matching the VM public key |
| `AZURE_VM_SSH_HOST_KEY` | Trusted SSH host key or host-and-key line for the application VM |
| `ACR_NAME` | Azure Container Registry resource name |
| `AZURE_SUBSCRIPTION_ID` | Subscription context for the private runner's managed-identity Azure CLI |

Do not store private keys or Terraform state in the repository.

The `private-acr` organization runner group must allow only this repository
and the trusted workflow
`Kaerica/Project-foundation-and-secure-collaboration/.github/workflows/cd.yml@refs/heads/main`.
This manual restriction is essential: a self-hosted runner must not execute
untrusted pull-request code. The runner must be registered after the VM is
created, using a short-lived token from GitHub; do not put that token in
Terraform or the repository.

The CD workflow requires `AZURE_VM_SSH_HOST_KEY` before opening Ansible access.
Obtain the value from a verified SSH session to the VM or the VM administrator;
do not disable host-key checking or replace it with `ssh-keyscan` as a trust
source. A missing host key is a deployment prerequisite, not a reason to weaken
SSH verification.

For the current tunnel, store a complete `known_hosts` entry for
`[127.0.0.1]:2222`, including the key type and public key, for example:
`[127.0.0.1]:2222 ssh-ed25519 <verified-public-key>`. Obtain and verify the
public-key value independently before storing it in GitHub Actions secrets.
