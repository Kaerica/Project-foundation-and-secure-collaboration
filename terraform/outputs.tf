output "resource_group_name" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.inventory.name
}

output "public_ip_address" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.inventory.ip_address
}

output "application_url" {
  description = "Inventory Manager URL"
  value       = "http://${azurerm_public_ip.inventory.ip_address}:3000"
}

output "vm_id" {
  description = "Azure VM resource ID"
  value       = azurerm_linux_virtual_machine.inventory.id
}