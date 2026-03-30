# Data Model: Azure Temporal Infrastructure (Feature 003)

**Branch**: `003-azure-temporal-infra` | **Date**: 2026-03-30

This feature is pure infrastructure-as-code — there is no application data model. This document
describes the **Terraform resource model**: the entities (resources), their key attributes, and
the dependency relationships between modules.

Architecture: public endpoints for AKS and PostgreSQL; Key Vault public with RBAC-only access.
No VNet, private endpoints, private DNS zones, or VPN Gateway.

---

## Module Dependency Graph

```
resource-group (existing)
    ├── aks           (depends on: resource-group)
    │   └── key-vault (depends on: aks — needs UAMI principal_id and outbound IP)
    └── postgresql    (depends on: resource-group + aks — needs aks_outbound_ip for firewall rule)
```

All modules depend on `resource-group` for the shared resource group name output.
`postgresql` depends on `aks` only for the outbound public IP (firewall rule).
`key-vault` depends on `aks` only for the ESO UAMI `principal_id` (RBAC assignment).

---

## Entity: AKS Cluster (`modules/azure-aks`)

| Attribute | Value / Type | Notes |
|-----------|-------------|-------|
| `azurerm_public_ip.name` | `homeschoolio-{env}-pip-aks-outbound` | Static, Standard SKU — pre-allocated for firewall rule determinism |
| `azurerm_kubernetes_cluster.name` | `homeschoolio-{env}-aks-temporal` | |
| `dns_prefix` | `homeschoolio-{env}` | Replaces `dns_prefix_private_cluster` |
| `private_cluster_enabled` | omitted (false) | Public API server |
| `oidc_issuer_enabled` | `true` | Required for Workload Identity (AzureRM ≥ 3.11) |
| `workload_identity_enabled` | `true` | AzureRM ≥ 3.28 |
| `identity.type` | `SystemAssigned` | |
| `default_node_pool.vm_size` | `Standard_D2s_v3` | FR-001; env-parameterized |
| `default_node_pool.node_count` | `1` (dev), `3` (staging/prod) | |
| `default_node_pool.vnet_subnet_id` | omitted | No customer VNet |
| `network_profile.network_plugin` | `kubenet` | Simpler without customer VNet |
| `network_profile.service_cidr` | `10.1.0.0/16` | K8s ClusterIP range |
| `network_profile.dns_service_ip` | `10.1.0.10` | |
| `network_profile.load_balancer_profile.outbound_ip_address_ids` | `[azurerm_public_ip.aks_outbound.id]` | Pre-allocated static IP |
| `api_server_access_profile.authorized_ip_ranges` | `var.api_server_authorized_ip_ranges` | list(string) of operator CIDRs |
| `node_resource_group` | `homeschoolio-{env}-rg-aks-nodes` | Explicit naming for convention compliance |
| `azurerm_user_assigned_identity.eso.name` | `homeschoolio-{env}-id-eso` | UAMI for External Secrets Operator |
| `azurerm_federated_identity_credential.name` | `homeschoolio-{env}-fic-eso` | Binds AKS OIDC + ESO K8s ServiceAccount |

**Federated Credential Subject**: `system:serviceaccount:{eso_namespace}:{eso_service_account_name}` — deployment layer must match exactly.

**Key Outputs**:
- `aks_cluster_name`
- `aks_cluster_id`
- `oidc_issuer_url`
- `aks_outbound_ip` — IPv4 string from `azurerm_public_ip.aks_outbound.ip_address`
- `eso_identity_client_id` — deployment layer annotates ESO ServiceAccount with this
- `eso_identity_principal_id` — key-vault module uses for RBAC assignment

**Variables removed from prior design**:
- `vnet_id`, `aks_subnet_id`, `aks_private_dns_zone_id` — no longer needed

---

## Entity: PostgreSQL Flexible Server (`modules/azure-postgresql`)

| Attribute | Value / Type | Notes |
|-----------|-------------|-------|
| `azurerm_postgresql_flexible_server.name` | `homeschoolio-{env}-psql-temporal` | |
| `sku_name` | `GP_Standard_D2s_v3` (dev) | Env-parameterized for staging/prod |
| `version` | `"16"` | Temporal-compatible; latest supported (13–16) |
| `delegated_subnet_id` | omitted | Public endpoint — no VNet injection |
| `private_dns_zone_id` | omitted | Public endpoint — no VNet injection |
| `public_network_access_enabled` | `true` | FR-002; requires AzureRM ≥ 3.27 |
| `storage_mb` | `32768` (dev) | Env-parameterized for staging/prod |
| `administrator_login` | `"psqladmin"` | Stored in Key Vault |
| `administrator_password` | sensitive var | Sourced from `TF_VAR_pg_admin_password` |
| **Firewall rule: allow-aks-outbound** | `start_ip = aks_outbound_ip`, `end_ip = aks_outbound_ip` | Restricts access to AKS cluster outbound IP only |
| **Database: temporal** | `UTF8` / `en_US.utf8` | `lifecycle { prevent_destroy = true }` |
| **Database: temporal_visibility** | `UTF8` / `en_US.utf8` | `lifecycle { prevent_destroy = true }` |
| `max_connections` (config) | `"300"` | Default (100) insufficient for Temporal; triggers restart |
| `shared_preload_libraries` (config) | `"pg_stat_statements"` | Observability; triggers restart |
| `azure.extensions` (config) | `"PG_STAT_STATEMENTS"` | Must allowlist before library loads |

**Key Outputs**:
- `postgresql_server_fqdn`
- `postgresql_server_id`
- `temporal_database_name` (`"temporal"`)
- `temporal_visibility_database_name` (`"temporal_visibility"`)

**Variables removed from prior design**:
- `postgres_delegated_subnet_id`, `postgres_private_dns_zone_id` — replaced by `aks_outbound_ip`

**New variable**:
- `aks_outbound_ip` — string, IPv4 address; consumed from `aks` dependency output

---

## Entity: Key Vault (`modules/azure-key-vault`)

| Attribute | Value / Type | Notes |
|-----------|-------------|-------|
| `azurerm_key_vault.name` | `homeschoolio-{env}-kv-tmp` | Max 24 chars; "temporal" exceeds limit |
| `sku_name` | `"standard"` | Lowest cost per Principle VI |
| `rbac_authorization_enabled` | `true` | v3.x argument name; RBAC mode; mutually exclusive with access_policy blocks |
| `public_network_access_enabled` | `true` | FR-004; no network firewall |
| `network_acls.default_action` | `"Allow"` | Explicitly set to prevent drift (cannot remove once set) |
| `network_acls.bypass` | `"AzureServices"` | Required by provider when block is present |
| `purge_protection_enabled` | `false` (dev) / `true` (staging, prod) | Immutable once set to true |
| `soft_delete_retention_days` | `7` (dev) / `90` (staging, prod) | Immutable after first apply |
| **Secret: pg-admin-password** | sensitive string | PostgreSQL admin password |
| **Secret: pg-admin-username** | `"psqladmin"` | |
| **RBAC: ESO UAMI → KV** | `Key Vault Secrets User` | Read secrets |
| **RBAC: Terraform runner → KV** | `Key Vault Secrets Officer` | Write secrets during provisioning |

**Key Outputs**:
- `key_vault_id`
- `key_vault_uri`

**Resources removed from prior design**:
- `azurerm_private_endpoint` — no private networking
- `azurerm_private_dns_zone_group` — no private networking

**Variables removed from prior design**:
- `private_endpoints_subnet_id`, `keyvault_private_dns_zone_id`

---

## Variable Contract (Cross-Module)

Variables that must be consistent across all modules (passed via Terragrunt root `inputs`):

| Variable | Type | Source | Consumers |
|----------|------|--------|-----------|
| `project` | `string` | root `terragrunt.hcl` | all modules |
| `environment` | `string` | root `terragrunt.hcl` | all modules |
| `location` | `string` | root `terragrunt.hcl` | all modules |
| `owner` | `string` | env `terragrunt.hcl` | all modules (tagging) |
| `api_server_authorized_ip_ranges` | `list(string)` | env `terragrunt.hcl` | azure-aks |
| `eso_namespace` | `string` | env `terragrunt.hcl` | azure-aks |
| `eso_service_account_name` | `string` | env `terragrunt.hcl` | azure-aks |
| `node_count` | `number` | env `terragrunt.hcl` | azure-aks (1 dev / 3 staging+prod) |
| `aks_outbound_ip` | `string` | aks dependency output | azure-postgresql (firewall rule) |
| `eso_identity_principal_id` | `string` | aks dependency output | azure-key-vault (RBAC assignment) |
| `pg_admin_password` | `string` (sensitive) | `TF_VAR_pg_admin_password` env var | azure-postgresql, azure-key-vault |
| `postgresql_sku_name` | `string` | env `terragrunt.hcl` | azure-postgresql (`GP_Standard_D2s_v3` dev) |

---

## State Backend Containers

One state key per Terragrunt root in the existing `homeschooliostfstate` account:

| Terragrunt Root | Container | State Key |
|-----------------|-----------|-----------|
| `dev/aks` | `homeschoolio-dev-infra-tfstate` | `environments/dev/aks/terraform.tfstate` |
| `dev/postgresql` | `homeschoolio-dev-infra-tfstate` | `environments/dev/postgresql/terraform.tfstate` |
| `dev/key-vault` | `homeschoolio-dev-infra-tfstate` | `environments/dev/key-vault/terraform.tfstate` |
| `staging/*` | `homeschoolio-staging-infra-tfstate` | same key pattern |
| `production/*` | `homeschoolio-production-infra-tfstate` | same key pattern |
