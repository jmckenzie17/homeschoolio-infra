output "postgresql_server_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL Flexible Server (resolves to a private IP within the VNet)."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgresql_server_id" {
  description = "Resource ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "temporal_database_name" {
  description = "Name of the Temporal core workflow state database."
  value       = azurerm_postgresql_flexible_server_database.temporal.name
}

output "temporal_visibility_database_name" {
  description = "Name of the Temporal Advanced Visibility database."
  value       = azurerm_postgresql_flexible_server_database.temporal_visibility.name
}
