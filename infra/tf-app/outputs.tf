output "resource_group_name" {
  description = "The name of the application resource group."
  value       = azurerm_resource_group.app.name
}

output "resource_group_id" {
  description = "The Azure resource ID of the application resource group."
  value       = azurerm_resource_group.app.id
}
