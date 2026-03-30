package main

import rego.v1

# Required tags on every taggable Azure resource per constitution Infrastructure Standards.
required_tags := {"Project", "Environment", "ManagedBy", "Owner"}

# AzureRM resource types that do not support the `tags` argument.
non_taggable_types := {
  "azurerm_federated_identity_credential",
  "azurerm_role_assignment",
  "azurerm_postgresql_flexible_server_firewall_rule",
  "azurerm_postgresql_flexible_server_database",
  "azurerm_postgresql_flexible_server_configuration",
  "azurerm_key_vault_secret",
}

deny contains msg if {
  resource := input.resource_changes[_]

  # Only evaluate resources being created or updated (not no-op or deleted)
  action := resource.change.actions[_]
  action != "no-op"
  action != "delete"

  # Skip data sources (address starts with "data.")
  not startswith(resource.address, "data.")

  # Skip resource types that do not support tags in the AzureRM provider.
  not non_taggable_types[resource.type]

  tag := required_tags[_]
  not resource.change.after.tags[tag]

  msg := sprintf(
    "Resource %s (%s) is missing required tag: %s",
    [resource.address, resource.type, tag],
  )
}
