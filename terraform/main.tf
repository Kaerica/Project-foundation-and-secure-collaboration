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

resource "azurerm_subnet" "inventory" {
  name                 = "subnet-inventory"
  resource_group_name  = azurerm_resource_group.inventory.name
  virtual_network_name = azurerm_virtual_network.inventory.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "inventory" {
  name                = "nsg-inventory-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-application"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "inventory" {
  subnet_id                 = azurerm_subnet.inventory.id
  network_security_group_id = azurerm_network_security_group.inventory.id
}

resource "azurerm_public_ip" "inventory" {
  name                = "pip-inventory-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "inventory" {
  name                = "nic-inventory-${var.environment}"
  location            = azurerm_resource_group.inventory.location
  resource_group_name = azurerm_resource_group.inventory.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.inventory.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.inventory.id
  }
}

resource "azurerm_network_interface_security_group_association" "inventory" {
  network_interface_id      = azurerm_network_interface.inventory.id
  network_security_group_id = azurerm_network_security_group.inventory.id
}

resource "azurerm_linux_virtual_machine" "inventory" {
  name                = "vm-inventory-${var.environment}"
  resource_group_name = azurerm_resource_group.inventory.name
  location            = azurerm_resource_group.inventory.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.inventory.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  custom_data = filebase64("${path.module}/cloud-init.yaml")

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