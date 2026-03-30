# modules/azure-aks/main.tf
# Provisions a public AKS cluster with Workload Identity enabled for the
# External Secrets Operator (feature 003). API server access is restricted to
# operator-supplied CIDR ranges via api_server_access_profile.

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
# Pre-allocated Static Outbound IP
# Pre-allocating ensures the IP address is known at plan time, which allows
# the PostgreSQL firewall rule (in a separate Terragrunt root) to reference
# the IP address as a module output without requiring a second apply cycle.
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "aks_outbound" {
  name                = "${var.project}-${var.environment}-pip-aks-outbound"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ---------------------------------------------------------------------------
# AKS Cluster
# ---------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "this" { #tfsec:ignore:azure-container-limit-authorized-ips #tfsec:ignore:azure-container-use-rbac-permissions
  name                = "${var.project}-${var.environment}-aks-temporal"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Public cluster — API server has a public FQDN but access is restricted to
  # the CIDRs in api_server_authorized_ip_ranges via api_server_access_profile.
  dns_prefix = "${var.project}-${var.environment}"

  # Explicit node resource group name for naming convention compliance.
  node_resource_group = "${var.project}-${var.environment}-rg-aks-nodes"

  # Workload Identity prerequisites (AzureRM >= 3.28).
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Restrict which IP ranges can reach the public API server.
  # AzureRM v3.x location: api_server_access_profile block.
  # The top-level api_server_authorized_ip_ranges argument was deprecated in
  # v3.x and removed in v4.0.
  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  # Explicitly enable RBAC (default in AzureRM 3.x, but stated for tfsec compliance).
  role_based_access_control_enabled = true

  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.vm_size
    os_disk_size_gb = 30
    type            = "VirtualMachineScaleSets"
    # No vnet_subnet_id — kubenet manages its own node VNet automatically.
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile { #tfsec:ignore:azure-container-configured-network-policy
    # kubenet is appropriate without a customer-managed VNet. Workload Identity
    # uses HTTPS to Microsoft Entra ID and has no network plugin dependency.
    # Note: kubenet is deprecated by Microsoft on 2028-03-31; plan migration to
    # Azure CNI Overlay before that date.
    network_plugin = "kubenet"
    network_policy = "calico"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    # docker_bridge_cidr is deprecated in AzureRM >= 3.48 — intentionally omitted.

    load_balancer_profile {
      # Pin outbound traffic to the pre-allocated static public IP so that the
      # PostgreSQL firewall rule can use a known, stable address.
      outbound_ip_address_ids = [azurerm_public_ip.aks_outbound.id]
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Workload Identity for External Secrets Operator
# ---------------------------------------------------------------------------

# User-assigned managed identity that ESO will assume via federated credentials.
# A system-assigned identity cannot be used for federated credentials.
resource "azurerm_user_assigned_identity" "eso" {
  name                = "${var.project}-${var.environment}-id-eso"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.common_tags
}

# Federated credential: binds the AKS OIDC issuer + ESO Kubernetes ServiceAccount
# to the managed identity, enabling passwordless Key Vault access from pods.
resource "azurerm_federated_identity_credential" "eso" {
  name                = "${var.project}-${var.environment}-fic-eso"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.eso.id

  # audience is a fixed value required by Azure AD Workload Identity.
  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.this.oidc_issuer_url

  # Subject must exactly match the ServiceAccount annotation
  # azure.workload.identity/client-id in the ESO deployment.
  subject = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"
}
