package main

# Enforce resource naming convention: {project}-{environment}-{resource-type}-{descriptor}
# Pattern: one or more lowercase alphanumeric segments separated by hyphens, minimum 4 segments.
# Example: homeschoolio-prod-nsg-web
naming_pattern := `^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+-[a-z0-9][a-z0-9-]*$`

# Resource types where we enforce naming on the `name` attribute.
# Extend this list as new resource types are added.
enforced_types := {
  "azurerm_resource_group",
  "azurerm_virtual_network",
  "azurerm_subnet",
  "azurerm_network_security_group",
  "azurerm_storage_account",
  "azurerm_key_vault",
  "azurerm_container_registry",
  "azurerm_kubernetes_cluster",
  "azurerm_linux_virtual_machine",
  "azurerm_app_service",
  "azurerm_function_app",
}

deny[msg] {
  resource := input.resource_changes[_]

  action := resource.change.actions[_]
  action != "no-op"
  action != "delete"

  not startswith(resource.address, "data.")

  enforced_types[resource.type]

  name := resource.change.after.name
  not regex.match(naming_pattern, name)

  msg := sprintf(
    "Resource %s has name %q which does not match required convention {project}-{environment}-{type}-{descriptor}",
    [resource.address, name],
  )
}
