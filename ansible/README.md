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
3000.

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
  -e container_registry_login_server="<ACTUAL_ACR_LOGIN_SERVER>" \
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

1. logs in to Azure,
2. builds the Docker image,
3. pushes only the Git SHA-tagged image to ACR,
4. opens an Azure Bastion tunnel,
5. runs this playbook through Ansible,
6. verifies `/health` and the running image ID, and
7. closes the tunnel.

The Git SHA tag identifies the exact commit used to build an image. It is not
automatically immutable: registry-level tag immutability must be enabled and
configured separately in Azure Container Registry.

Terraform has upgraded Bastion to Standard and Azure state confirms native
client tunnelling is enabled. Standard Bastion may add ongoing cost. The
end-to-end GitHub deployment still needs its production secrets and has not
yet been verified.

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

Do not store private keys or Terraform state in the repository.

The CD workflow requires `AZURE_VM_SSH_HOST_KEY` before opening Ansible access.
Obtain the value from a verified SSH session to the VM or the VM administrator;
do not disable host-key checking or replace it with `ssh-keyscan` as a trust
source. A missing host key is a deployment prerequisite, not a reason to weaken
SSH verification.

For the current tunnel, store a complete `known_hosts` entry for
`[127.0.0.1]:2222`, including the key type and public key, for example:
`[127.0.0.1]:2222 ssh-ed25519 <verified-public-key>`. Obtain and verify the
public-key value independently before storing it in GitHub Actions secrets.
