output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster. Required to configure additional federated identity credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "eso_identity_client_id" {
  description = "Client ID of the ESO user-assigned managed identity. The deployment layer must annotate the ESO ServiceAccount with azure.workload.identity/client-id set to this value."
  value       = azurerm_user_assigned_identity.eso.client_id
}

output "eso_identity_principal_id" {
  description = "Principal (object) ID of the ESO user-assigned managed identity. Used by the Key Vault module to assign RBAC roles."
  value       = azurerm_user_assigned_identity.eso.principal_id
}

output "aks_outbound_ip" {
  description = "Public outbound IP of the AKS load balancer. Used by the postgresql module to create a firewall rule restricting database access to the AKS cluster."
  value       = azurerm_public_ip.aks_outbound.ip_address
}
