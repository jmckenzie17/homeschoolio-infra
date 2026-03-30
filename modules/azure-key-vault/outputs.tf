output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  description = "Vault URI of the Key Vault. Used by ESO ClusterSecretStore and application deployments."
  value       = azurerm_key_vault.this.vault_uri
}
