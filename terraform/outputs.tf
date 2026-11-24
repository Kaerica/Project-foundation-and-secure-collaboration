output "resource_group_name" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.inventory.name
}

output "bastion_public_ip_address" {
  description = "Public IP address used to connect through Azure Bastion"
  value       = azurerm_public_ip.bastion.ip_address
}

output "application_private_ip_address" {
  description = "Private IP address of the application VM"
  value       = azurerm_network_interface.inventory.private_ip_address
}

output "application_public_ip_address" {
  description = "Public IP address of the HTTP application load balancer"
  value       = azurerm_public_ip.application.ip_address
}

output "application_public_url" {
  description = "Public HTTP URL for the read-only application endpoint"
  value       = "http://${azurerm_public_ip.application.ip_address}"
}

output "postgresql_fqdn" {
  description = "Private DNS hostname of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.inventory.fqdn
}

output "postgresql_database_name" {
  description = "Database name used by the Inventory Manager"
  value       = azurerm_postgresql_flexible_server_database.inventory.name
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.inventory.login_server
}

output "container_registry_name" {
  description = "Azure Container Registry resource name"
  value       = azurerm_container_registry.inventory.name
}

output "vm_id" {
  description = "Azure VM resource ID"
  value       = azurerm_linux_virtual_machine.inventory.id
}