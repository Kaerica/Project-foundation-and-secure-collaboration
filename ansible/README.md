# Ansible configuration and deployment

This playbook configures the Azure Ubuntu VM provisioned by `terraform/` and
deploys the Inventory Manager using the repository's existing Docker Compose
configuration.

## Directory structure

- `ansible.cfg` selects this directory's inventory and keeps SSH host-key
  checking enabled.
- `inventory.ini` identifies the VM, SSH administrator, and private-key path.
- `playbook.yml` installs required packages, deploys Compose, checks health,
  and applies a validated SSH hardening drop-in.

## Prerequisites

- The VM must already exist and be reachable. This playbook does not create,
  destroy, or modify Terraform infrastructure.
- Terraform must be initialized and have the state for the VM in
  `terraform/`.
- Ansible must run on a supported Linux control node (for example, WSL or a
  Linux machine). Ansible is not supported as a native Windows control node.
- The control node needs SSH access and internet access to clone the public
  application repository. The VM needs apt and GitHub access to install
  packages and check out the application.
- Use the SSH private key matching `ssh_public_key` configured for this VM.

Install Ansible on Ubuntu/WSL if needed:

```bash
sudo apt update
sudo apt install -y ansible
ansible --version
```

The playbook uses Ubuntu's `apt` packages because Terraform provisions Ubuntu
24.04. It installs `docker.io`, `docker-compose-v2`, `git`, and
`openssh-server` only when they are not already installed.

## Get the VM public IP

From PowerShell at the repository root, read the output from the existing
Terraform state:

```powershell
terraform -chdir=terraform output -raw public_ip_address
```

If the provider plugins are not initialized, `terraform -chdir=terraform init`
downloads providers but does not create or change Azure resources. If there is
no Terraform state, `output` cannot discover a VM from configuration alone.
Restore the correct existing state or obtain the VM's current public IP from
the Azure Portal; do not run `terraform apply` merely to get the address.

## Configure the inventory and SSH key

Replace `REPLACE_WITH_TERRAFORM_PUBLIC_IP` in `inventory.ini` with the exact
`public_ip_address` output. The checked-in inventory uses `azureuser` and
`~/.ssh/alu-devops` to match the example Terraform variables. Confirm the
actual VM's `admin_username` and the private key that matches its
`ssh_public_key`; update the inventory values if they differ. The IP is
intentionally not guessed or committed because it depends on the deployed
Terraform state. To update the inventory directly from PowerShell at the
repository root:

```powershell
$publicIp = (terraform -chdir=terraform output -raw public_ip_address).Trim()
if ($LASTEXITCODE -ne 0 -or -not $publicIp) { throw "Terraform public_ip_address is unavailable." }
$inventoryPath = "ansible/inventory.ini"
$inventory = (Get-Content $inventoryPath -Raw).Replace("REPLACE_WITH_TERRAFORM_PUBLIC_IP", $publicIp)
Set-Content $inventoryPath -Value $inventory -NoNewline
```

For a Windows key used from WSL, copy it into the WSL user's SSH directory and
restrict its permissions (replace the Windows path if your key is elsewhere):

```powershell
wsl -e bash -lc "mkdir -p ~/.ssh && cp /mnt/c/Users/HP/.ssh/alu-devops ~/.ssh/alu-devops && chmod 600 ~/.ssh/alu-devops"
```

Never copy a private key into this repository or print/share its contents.
From WSL, verify that the file exists and has owner-only permissions:

```bash
stat -c '%a %n' ~/.ssh/alu-devops
```

Expected permissions are `600`. If your key is elsewhere, change
`ansible_ssh_private_key_file` in `inventory.ini` to its WSL path. The path
must point to the private key, not its `.pub` file.

## Check connectivity and inventory

Run these commands from `ansible/` in WSL:

```bash
ansible-inventory -i inventory.ini --list
ansible inventory -i inventory.ini -m ansible.builtin.ping
```

The inventory output should show the real Terraform IP and correct SSH user.
The ping must succeed before running the playbook; when the playbook runs, it
only hardens SSH after Ansible has successfully connected as the non-root VM
administrator.

If Ansible warns that it ignored `ansible.cfg` because the repository is under
`/mnt/c` (a world-writable mount), specify the config explicitly for commands:

```bash
export ANSIBLE_CONFIG="$PWD/ansible.cfg"
```

Alternatively, run from a Linux filesystem directory. Host-key checking stays
enabled; accept the VM's verified host key rather than disabling the check.

## Run the playbook

Validate syntax and then apply the playbook:

```bash
ansible-playbook -i inventory.ini --syntax-check playbook.yml
ansible-playbook -i inventory.ini playbook.yml
```

The playbook installs required Ubuntu packages only when missing, ensures
Docker is enabled and running, and checks out the repository to
`/opt/inventory`. It copies `.env.example` only when `/opt/inventory/.env`
does not exist, validates `docker compose config`, and starts the Compose
service when the checkout/environment changed or the service is not running.
The Compose file builds the existing `Dockerfile`, maps the configured host
port (default TCP/3000) to container TCP/3000, and supplies its restart and
health-check policies. If cloud-init's standalone `inventory-manager`
container is running, the playbook stops it to release TCP/3000; it does not
remove that container or remove unrelated Compose containers.

The playbook does not change firewall rules. Terraform's Azure NSG already
allows SSH on TCP/22 only from `allowed_ssh_cidr` and the app on TCP/3000.
Docker-published ports can bypass host UFW rules, so the Azure NSG remains the
inbound firewall for this deployment. The app port is currently allowed from
all source addresses in Terraform; restrict that source range in Terraform
only if public access is not intended.

## Verify the deployment

Check Docker and Compose on the VM:

```bash
ansible inventory -i inventory.ini -b -m ansible.builtin.command -a "docker --version"
ansible inventory -i inventory.ini -b -m ansible.builtin.command -a "docker compose version"
ansible inventory -i inventory.ini -b -m ansible.builtin.command -a "docker compose -f /opt/inventory/docker-compose.yml ps"
```

Check the health endpoint locally on the VM and through the public endpoint:

```bash
ansible inventory -i inventory.ini -b -m ansible.builtin.uri -a "url=http://127.0.0.1:3000/health status_code=200"
```

The expected response is `{"status":"ok"}`. To inspect application logs:

```bash
ansible inventory -i inventory.ini -b -m ansible.builtin.command -a "docker compose -f /opt/inventory/docker-compose.yml logs --tail=100 inventory-manager"
```

From PowerShell at the repository root, test the public endpoint using the
same Terraform output:

```powershell
$publicIp = terraform -chdir=terraform output -raw public_ip_address
Invoke-RestMethod "http://${publicIp}:3000/health"
```

## Verify the firewall configuration

Terraform's NSG, rather than a host firewall, provides inbound filtering.
From PowerShell at the repository root, list the NSGs in the provisioned
resource group:

```powershell
$resourceGroup = terraform -chdir=terraform output -raw resource_group_name
az network nsg list --resource-group $resourceGroup --output table
```

The NSG name is `nsg-inventory-<environment>`; `environment` is configured in
`terraform/terraform.tfvars` (or defaults to `dev`). List its rules with:

```powershell
az network nsg rule list --resource-group $resourceGroup --nsg-name "nsg-inventory-dev" --output table
```

Replace `dev` if the Terraform environment value differs. Confirm TCP/22 is
limited to `allowed_ssh_cidr` and TCP/3000 has the intended application
source range.

## Troubleshooting

- **Terraform output fails:** Confirm `terraform/` is initialized and the
correct existing state is present. If state is missing, retrieve it or
obtain the IP through Azure; do not apply or recreate infrastructure just
to discover the address.
- **SSH timeout:** Confirm the VM is running, the IP is current, inbound TCP/22
is allowed by its NSG, and your current public IP is within
`allowed_ssh_cidr`.
- **SSH permission denied:** Confirm the inventory user matches
`admin_username` and the private key matches the public key used to create
the VM. Check key permissions and test from WSL using the host and user
already set in `inventory.ini`:

```bash
ssh_target=$(sed -n 's/^inventory_vm ansible_host=\([^ ]*\) ansible_user=\([^ ]*\).*/\2@\1/p' inventory.ini)
ssh -i ~/.ssh/alu-devops "$ssh_target"
```

- **Compose config fails:** Check that `/opt/inventory/.env` exists and that
the VM can reach GitHub. The playbook uses `.env.example` only when the
`.env` file is absent; it does not overwrite existing environment settings.
- **Port 3000 is already in use:** The playbook stops the cloud-init container
named `inventory-manager`. If another service owns the port, inspect it
before stopping or changing anything.
- **Health check fails:** Inspect Compose status and logs using the commands
above; also confirm the NSG permits inbound TCP/3000 if testing externally.
- **SSH reload validation fails:** The playbook validates the drop-in and
complete SSH configuration before its reload handler can run. Correct the
reported SSH configuration issue and rerun; password authentication is not
changed by this playbook.
