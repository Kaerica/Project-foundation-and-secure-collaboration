# Ansible (legacy deployment only)

The playbook in this directory belongs to the earlier public-IP VM and Docker
Compose deployment. It is **not compatible with the current Terraform stack**
and must not be run against the Terraform VM: Terraform cloud-init owns the
systemd-managed ACR container and the VM connects to Azure Database for
PostgreSQL.

The current inventory deliberately contains
`REPLACE_WITH_LEGACY_VM_PUBLIC_IP`; it is not an Azure output and must not be
replaced with the current Terraform VM's private or Bastion address. Do not
restore the old checked-in public IP.

For the current deployment, use Terraform and cloud-init as the source of
truth. The application health endpoint is `http://<VM-private-IP>:3000/health`
from inside the VNet. Connect to the VM with Azure Bastion; do not use this
legacy playbook to install Compose, replace the container, or modify its
database configuration.

The legacy files are retained for historical reference only. If the team
chooses to make Ansible the deployment owner, first redesign the playbook to
preserve the current managed-identity ACR pull, systemd service, and external
PostgreSQL configuration, then test it against a disposable environment.
