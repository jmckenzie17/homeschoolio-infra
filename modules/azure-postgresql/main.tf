# modules/azure-postgresql/main.tf
# Provisions an Azure Database for PostgreSQL Flexible Server with a public
# endpoint restricted to the AKS outbound IP via a firewall rule, pre-seeded
# with Temporal's two required databases (feature 003).

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
  features {}
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
}

# ---------------------------------------------------------------------------
# PostgreSQL Flexible Server — Public Endpoint
# ---------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "${var.project}-${var.environment}-psql-temporal-01"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Public endpoint: access is restricted to the AKS outbound IP via the
  # firewall rule below. delegated_subnet_id and private_dns_zone_id are
  # intentionally omitted (no VNet injection).
  public_network_access_enabled = true

  sku_name               = var.sku_name
  storage_mb             = var.storage_mb
  version                = var.pg_version
  administrator_login    = var.pg_admin_username
  administrator_password = var.pg_admin_password

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Firewall Rule
# Allow connections only from the AKS cluster's static outbound public IP.
# Firewall rule arguments require IPv4 address strings — NOT CIDR notation.
# ---------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_firewall_rule" "aks_outbound" {
  name             = "allow-aks-outbound"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.aks_outbound_ip
  end_ip_address   = var.aks_outbound_ip
}

# ---------------------------------------------------------------------------
# Databases
# Temporal requires two databases: temporal (workflow state) and
# temporal_visibility (workflow search/filter queries).
# prevent_destroy is set per provider documentation to guard against
# accidental data loss during terraform destroy or module refactoring.
# ---------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_database" "temporal" {
  name      = "temporal"
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = "en_US.utf8"
  charset   = "UTF8"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server_database" "temporal_visibility" {
  name      = "temporal_visibility"
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = "en_US.utf8"
  charset   = "UTF8"

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Server Configurations
# azure.extensions must be allowlisted before shared_preload_libraries
# references the extension. max_connections and shared_preload_libraries
# are static parameters that trigger an automatic Azure-managed server
# restart — apply them together in the same terraform apply.
# ---------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_configuration" "azure_extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "PG_STAT_STATEMENTS"
}

resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.this.id
  # Default (50 * vCores = 100) is insufficient for Temporal's connection pool.
  value = "300"

  depends_on = [azurerm_postgresql_flexible_server_configuration.azure_extensions]
}

resource "azurerm_postgresql_flexible_server_configuration" "shared_preload_libraries" {
  name      = "shared_preload_libraries"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "pg_stat_statements"

  depends_on = [azurerm_postgresql_flexible_server_configuration.azure_extensions]
}
