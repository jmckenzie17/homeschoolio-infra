# modules/azure-key-vault/main.tf
# Provisions an Azure Key Vault in RBAC mode with PostgreSQL credentials stored
# as secrets and ESO Workload Identity wired for secret access (feature 003).

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  use_oidc                   = true
  skip_provider_registration = true
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "opentofu"
    Owner       = var.owner
  }

  # Key Vault names are limited to 24 characters. The full form
  # "${var.project}-${var.environment}-kv-temporal" exceeds this limit for
  # "homeschoolio" (28 chars). Abbreviated to "-kv-tmp" (23 chars max).
  key_vault_name = "${var.project}-${var.environment}-kv-tmp"
}

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Key Vault
# enable_rbac_authorization = true enables RBAC-only access control.
# RBAC mode and access_policy blocks are mutually exclusive.
#
# network_acls is included explicitly with default_action = "Allow" from the
# start. Per provider issue #27609, network_acls cannot be removed after
# initial apply, so including it now prevents future plan drift.
# ---------------------------------------------------------------------------

#tfsec:ignore:azure-keyvault-specify-network-acl
resource "azurerm_key_vault" "this" {
  name                = local.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = true
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = true

  network_acls {
    default_action = "Allow"
    # bypass is required by the provider when the network_acls block is present.
    # "AzureServices" is a no-op with default_action = "Allow" but satisfies the schema.
    bypass = "AzureServices"
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# RBAC Role Assignments
# ---------------------------------------------------------------------------

# ESO user-assigned managed identity: read-only access to secrets.
resource "azurerm_role_assignment" "eso_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.eso_identity_principal_id
  principal_type       = "ServicePrincipal"
}

# Terraform runner (CI/CD OIDC identity): write access to create/update secrets.
resource "azurerm_role_assignment" "tf_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Secrets
# Secrets depend on the Secrets Officer role assignment being provisioned
# first; without it the Terraform runner cannot write to the vault.
# ---------------------------------------------------------------------------

resource "azurerm_key_vault_secret" "pg_admin_password" {
  name         = "pg-admin-password"
  value        = var.pg_admin_password
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.tf_secrets_officer]
}

resource "azurerm_key_vault_secret" "pg_admin_username" {
  name         = "pg-admin-username"
  value        = var.pg_admin_username
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.tf_secrets_officer]
}
