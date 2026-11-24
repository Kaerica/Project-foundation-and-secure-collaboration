terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "inventory" {
  name     = "rg-inventory-${var.environment}"
  location = var.location
}

resource "azurerm_virtual_network" "inventory" {
  name                = "vnet-inventory-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.inventory.name
  virtual_network_name = azurerm_virtual_network.inventory.name
  address_prefixes     = ["10.0.4.0/26"]
}

resource "azurerm_subnet" "application" {
  name                 = "subnet-inventory-app"
  resource_group_name  = azurerm_resource_group.inventory.name
  virtual_network_name = azurerm_virtual_network.inventory.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "database" {
  name                 = "subnet-inventory-db"
  resource_group_name  = azurerm_resource_group.inventory.name
  virtual_network_name = azurerm_virtual_network.inventory.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "postgresql-flexible-server"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_network_security_group" "database" {
  name                = "nsg-inventory-db-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name

  security_rule {
    name                       = "allow-postgresql-from-application"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_subnet.application.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.database.address_prefixes[0]
  }

  security_rule {
    name                       = "allow-postgresql-subnet-internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_subnet.database.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.database.address_prefixes[0]
  }

  security_rule {
    name                       = "allow-postgresql-to-storage"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.database.address_prefixes[0]
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "allow-postgresql-subnet-internal-outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_subnet.database.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.database.address_prefixes[0]
  }
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "inventory" {
  name                = "bastion-inventory-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_group" "application" {
  name                = "nsg-inventory-app-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name

  security_rule {
    name                       = "allow-ssh-from-bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.bastion.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-application-from-vnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "application" {
  subnet_id                 = azurerm_subnet.application.id
  network_security_group_id = azurerm_network_security_group.application.id
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "inventory" {
  name                = "nat-inventory-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "inventory" {
  nat_gateway_id       = azurerm_nat_gateway.inventory.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "application" {
  subnet_id      = azurerm_subnet.application.id
  nat_gateway_id = azurerm_nat_gateway.inventory.id
}

resource "azurerm_network_interface" "inventory" {
  name                = "nic-inventory-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.application.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "inventory" {
  name                = "vm-inventory-${var.environment}"
  resource_group_name = azurerm_resource_group.inventory.name
  location            = azurerm_resource_group.inventory.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true
  allow_extension_operations      = true

  network_interface_ids = [
    azurerm_network_interface.inventory.id
  ]

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    container_registry_name         = azurerm_container_registry.inventory.name
    container_registry_login_server = azurerm_container_registry.inventory.login_server
    container_image_tag             = var.container_image_tag
    postgresql_fqdn                 = azurerm_postgresql_flexible_server.inventory.fqdn
    postgresql_database_name        = azurerm_postgresql_flexible_server_database.inventory.name
    postgresql_admin_username       = var.postgresql_admin_username
    postgresql_admin_password_b64   = base64encode(var.postgresql_admin_password)
    postgresql_app_username         = var.postgresql_app_username
    postgresql_app_password_b64     = base64encode(var.postgresql_app_password)
  }))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "${var.environment}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.inventory.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "link-postgresql-${var.environment}"
  resource_group_name   = azurerm_resource_group.inventory.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = azurerm_virtual_network.inventory.id
  registration_enabled  = false
}

resource "azurerm_postgresql_flexible_server" "inventory" {
  name                          = var.postgresql_server_name
  resource_group_name           = azurerm_resource_group.inventory.name
  location                      = azurerm_resource_group.inventory.location
  version                       = "16"
  zone                          = "1"
  delegated_subnet_id           = azurerm_subnet.database.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgresql.id
  public_network_access_enabled = false
  administrator_login           = var.postgresql_admin_username
  administrator_password        = var.postgresql_admin_password
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7

  lifecycle {
    precondition {
      condition     = var.postgresql_admin_username != var.postgresql_app_username
      error_message = "The PostgreSQL application login must be different from the administrator login."
    }
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgresql,
    azurerm_subnet_network_security_group_association.database,
  ]
}

resource "azurerm_postgresql_flexible_server_database" "inventory" {
  name      = var.postgresql_database_name
  server_id = azurerm_postgresql_flexible_server.inventory.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_container_registry" "inventory" {
  name                          = var.container_registry_name
  resource_group_name           = azurerm_resource_group.inventory.name
  location                      = azurerm_resource_group.inventory.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
}

resource "azurerm_role_assignment" "registry_pull" {
  scope                = azurerm_container_registry.inventory.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine.inventory.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
