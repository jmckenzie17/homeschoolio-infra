# Research: Azure Temporal Self-Hosted Infrastructure (Feature 003)

**Branch**: `003-azure-temporal-infra` | **Date**: 2026-03-30

All decisions are grounded in: AzureRM provider `~> 3.0`, OpenTofu 1.6.2, Terragrunt 0.56.3,
constitution v1.1.0 (Principle VI: lowest-cost SKU that satisfies functional requirements),
and the existing module pattern in `modules/azure-resource-group/`.

Architecture: **Public endpoints** for AKS and PostgreSQL. No VNet, private endpoints, private DNS
zones, or VPN Gateway. Key Vault with public endpoint and RBAC-only access control.

---

## 1. Module Decomposition

**Decision**: Three reusable modules composed per environment via Terragrunt dependency graph.

```
modules/
  azure-aks/           # AKS cluster (public), node pool, outbound static IP, Workload Identity UAMI, federated credential
  azure-postgresql/    # Flexible Server (public endpoint), databases, server configurations, firewall rule
  azure-key-vault/     # Key Vault (RBAC mode, public), secrets, RBAC role assignments

environments/
  dev/
    resource-group/    # existing
    aks/               # dependency: resource-group
    postgresql/        # dependency: resource-group + aks (for outbound IP)
    key-vault/         # dependency: resource-group + aks (for UAMI principal_id)
```

**Rationale**: One Terragrunt root per logical domain per constitution Principle V (state isolation).
Each module has independent blast radius. Three modules is the minimum needed: VNet/VPN Gateway
are explicitly out of scope per clarification.

**Alternatives considered**:
- Single combined "temporal-stack" module — rejected: violates Principle V, produces enormous plan diffs.
- Community AKS module (Azure/aks/azurerm) — rejected: floating dependency; bypasses OPA naming/tagging policy.

---

## 2. AKS Public Cluster with Authorized IP Ranges

**Decision**: `api_server_access_profile { authorized_ip_ranges = var.api_server_authorized_ip_ranges }`.
Do NOT set `private_cluster_enabled = true`.

**Key arguments (AzureRM v3.x)**:
```hcl
dns_prefix = "${var.project}-${var.environment}"   # replaces dns_prefix_private_cluster

api_server_access_profile {
  authorized_ip_ranges = var.api_server_authorized_ip_ranges   # list(string) of CIDRs
}
```

**Rationale**: `api_server_authorized_ip_ranges` (top-level) was deprecated in AzureRM v3.x and
removed in v4.0. The v3.x location is the `api_server_access_profile` block.
`authorized_ip_ranges` is **mutually exclusive** with `private_cluster_enabled = true` — Azure
enforces this at the API level (private clusters have no public API server endpoint to restrict).

**Caveats**:
- To clear ranges after setting: pass `authorized_ip_ranges = []`. Removing the block silently
  no-ops in some v3.x sub-versions.
- Changing `authorized_ip_ranges` is an in-place update; no cluster replacement.
- Remove `private_cluster_enabled`, `private_cluster_public_fqdn_enabled`,
  `dns_prefix_private_cluster`, and `private_dns_zone_id` from the existing module entirely.

---

## 3. AKS Outbound IP for PostgreSQL Firewall

**Decision**: Pre-allocate a static `azurerm_public_ip` and assign it via
`network_profile.load_balancer_profile.outbound_ip_address_ids`. Use
`azurerm_public_ip.aks_outbound.ip_address` directly in the PostgreSQL firewall rule.

**Rationale**: `network_profile[0].load_balancer_profile[0].effective_outbound_ips` returns Azure
resource IDs (not IP strings) and is **unknown at plan time** for new clusters — causing the
PostgreSQL firewall rule to fail in the same apply. Pre-allocating the IP eliminates the
chicken-and-egg dependency.

**Implementation**:
```hcl
resource "azurerm_public_ip" "aks_outbound" {
  name              = "${var.project}-${var.environment}-pip-aks-outbound"
  allocation_method = "Static"
  sku               = "Standard"
  resource_group_name = var.resource_group_name
  location          = var.location
  tags              = local.common_tags
}

resource "azurerm_kubernetes_cluster" "this" {
  network_profile {
    network_plugin = "kubenet"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.aks_outbound.id]
    }
  }
}
```

**Output**: `aks_outbound_ip` (= `azurerm_public_ip.aks_outbound.ip_address`) — consumed by the
postgresql Terragrunt root to set the firewall rule.

**Alternatives considered**:
- Dynamic lookup via `azurerm_public_ip` data source on auto-provisioned IP — rejected: resource ID
  path requires fragile `split()` arithmetic; unknown at plan time.

---

## 4. AKS Network Plugin: Kubenet (No VNet)

**Decision**: `network_plugin = "kubenet"` with no `vnet_subnet_id` on the default node pool.

**Rationale**: Without a customer-managed VNet, kubenet is cleaner. Azure auto-manages the node VNet.
Azure CNI without an explicit `vnet_subnet_id` can produce provider validation errors in some v3.x
versions. Workload Identity uses HTTPS to Microsoft Entra ID — no network plugin dependency.

**Caveats**:
- Kubenet is deprecated by Microsoft on **2028-03-31**. Plan migration to Azure CNI Overlay before
  that date.
- Remove `vnet_id`, `aks_subnet_id`, `aks_private_dns_zone_id` variables from the module.
  The AKS system identity no longer needs Network Contributor on a VNet.
- `node_resource_group` explicit naming can be retained for naming convention compliance.

---

## 5. AKS Workload Identity

**Decision**: `oidc_issuer_enabled = true` + `workload_identity_enabled = true`. User-assigned
managed identity (UAMI) + OIDC federated credential bound to the ESO Kubernetes ServiceAccount.

**No changes from prior design** — Workload Identity has no network plugin prerequisite.

Resource chain (unchanged):
1. `azurerm_user_assigned_identity` — identity ESO assumes
2. `azurerm_federated_identity_credential` — binds AKS OIDC issuer URL + ESO ServiceAccount subject
3. `azurerm_role_assignment` — grants UAMI `Key Vault Secrets User` on Key Vault

```hcl
subject  = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"
audience = ["api://AzureADTokenExchange"]   # fixed value required by Azure AD
issuer   = azurerm_kubernetes_cluster.this.oidc_issuer_url
```

---

## 6. PostgreSQL Flexible Server — Public Endpoint

**Decision**: Omit `delegated_subnet_id` and `private_dns_zone_id`. Set
`public_network_access_enabled = true`. Use `azurerm_postgresql_flexible_server_firewall_rule`
to allow only the AKS outbound IP.

**Key arguments**:
```hcl
resource "azurerm_postgresql_flexible_server" "this" {
  public_network_access_enabled = true
  # delegated_subnet_id and private_dns_zone_id are OMITTED
  sku_name            = var.sku_name       # default: "GP_Standard_D2s_v3"
  version             = var.pg_version     # default: "16"
  administrator_login    = var.pg_admin_username
  administrator_password = var.pg_admin_password
  storage_mb          = var.storage_mb
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "aks_outbound" {
  name             = "allow-aks-outbound"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.aks_outbound_ip   # IPv4 string — NOT CIDR
  end_ip_address   = var.aks_outbound_ip
}
```

**Important**: Firewall rule arguments require IPv4 address strings, not CIDR notation.
`public_network_access_enabled` requires AzureRM ≥ 3.27.0.

**Databases and server config are unchanged** — Temporal still requires:
- `temporal` database (UTF8 / en_US.utf8) with `lifecycle { prevent_destroy = true }`
- `temporal_visibility` database (UTF8 / en_US.utf8) with `lifecycle { prevent_destroy = true }`
- `max_connections = "300"` (static parameter — triggers restart)
- `shared_preload_libraries = "pg_stat_statements"` (static parameter — triggers restart)
- `azure.extensions = "PG_STAT_STATEMENTS"` (must allowlist before library loads)

---

## 7. Azure Key Vault — Public Endpoint, RBAC Only

**Decision**: `rbac_authorization_enabled = true`, `public_network_access_enabled = true`,
`network_acls { default_action = "Allow"; bypass = "AzureServices" }`.

**Key arguments**:
```hcl
resource "azurerm_key_vault" "this" {
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = true
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}
```

**Rationale**: Per provider issue #27609, `network_acls` cannot be removed after initial apply.
Including it explicitly with `default_action = "Allow"` from the start prevents future plan drift.
`bypass = "AzureServices"` is a no-op with `Allow` but is required by the provider when the block
is present.

**Caveats**:
- Remove `private_endpoints_subnet_id` and `keyvault_private_dns_zone_id` variables.
- Remove `azurerm_private_endpoint` and `azurerm_private_dns_zone_group` resources.
- Remove `vnet` dependency from the key-vault Terragrunt roots.
- tfsec will flag `azure-keyvault-specify-network-acl`. Add
  `#tfsec:ignore:azure-keyvault-specify-network-acl` at the resource block.
- `purge_protection_enabled` and `soft_delete_retention_days` are immutable after first apply.

**Role assignments (unchanged)**:
- ESO UAMI → `Key Vault Secrets User` (read secrets)
- Terraform runner → `Key Vault Secrets Officer` (write secrets during provisioning)

---

## 8. OPA Policy — Resource Types

The existing `policies/naming.rego` `enforced_types` set must be extended:

```
azurerm_postgresql_flexible_server
azurerm_user_assigned_identity
azurerm_public_ip
```

`azurerm_key_vault` and `azurerm_kubernetes_cluster` are already in `enforced_types`.
`azurerm_virtual_network`, `azurerm_virtual_network_gateway` are no longer needed.

---

## 9. State Backend Containers

One state key per Terragrunt root in the existing `homeschooliostfstate` account, per
constitution Principle V. Existing container naming pattern: `homeschoolio-{env}-infra-tfstate`.

| Terragrunt Root | Container | State Key |
|-----------------|-----------|-----------|
| `dev/aks` | `homeschoolio-dev-infra-tfstate` | `environments/dev/aks/terraform.tfstate` |
| `dev/postgresql` | `homeschoolio-dev-infra-tfstate` | `environments/dev/postgresql/terraform.tfstate` |
| `dev/key-vault` | `homeschoolio-dev-infra-tfstate` | `environments/dev/key-vault/terraform.tfstate` |
| staging/production | same pattern | same pattern |
