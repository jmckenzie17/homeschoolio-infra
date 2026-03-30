# Tasks: Azure Temporal Self-Hosted Infrastructure

**Input**: Design documents from `/specs/003-azure-temporal-infra/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.
No test tasks are generated (not requested in spec).

**Architecture**: Public endpoints for AKS (restricted by `authorized_ip_ranges`) and PostgreSQL
(restricted by AKS outbound IP firewall rule). Key Vault public endpoint with RBAC-only access.
No VNet, private endpoints, private DNS zones, or VPN Gateway.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Correct existing module scaffolding to match the public-endpoint architecture decided
during clarification. Several modules and environment roots were pre-created for the old private
networking design; this phase removes stale artifacts and corrects the directory structure.

- [x] T001 Remove stale private-networking variables from `modules/azure-aks/variables.tf`: delete `vnet_id`, `aks_subnet_id`, `aks_private_dns_zone_id` variables (no longer consumed — no VNet)
- [x] T002 [P] Remove stale private-networking variables from `modules/azure-key-vault/variables.tf`: delete `private_endpoints_subnet_id`, `keyvault_private_dns_zone_id` variables
- [x] T003 Remove `azurerm_virtual_network_gateway` from `policies/naming.rego` `enforced_types` set (VPN Gateway module removed; leaving a stale enforced type causes spurious OPA failures if the plan JSON contains no gateway resource)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core scaffolding and OPA policy corrections that MUST be complete before any module
implementation begins.

**⚠️ CRITICAL**: No module implementation can begin until this phase is complete.

- [x] T004 Update `policies/naming.rego`: confirm `enforced_types` contains `"azurerm_postgresql_flexible_server"`, `"azurerm_user_assigned_identity"`, `"azurerm_public_ip"` (already added in prior work); verify `"azurerm_virtual_network_gateway"` is removed (T003); no other changes needed
- [x] T005 [P] Verify `modules/azure-aks/version.tf`, `modules/azure-postgresql/version.tf`, `modules/azure-key-vault/version.tf` each contain `module_version = "1.0.0"` (already created; confirm present and correct)

**Checkpoint**: Policy and version scaffolding confirmed — module implementation can now begin.

---

## Phase 3: User Story 1 — Provision AKS Cluster (Priority: P1) 🎯 MVP

**Goal**: Public AKS cluster with `authorized_ip_ranges` restricting API server access to
operator-provided CIDRs, a pre-allocated static outbound IP for deterministic PostgreSQL firewall
rules, and Workload Identity enabled for the External Secrets Operator.

**Independent Test**: `terragrunt apply` in `environments/dev/aks/` completes without errors;
`kubectl get nodes` returns 1 Ready node; `aks_outbound_ip` and `eso_identity_client_id` appear
in Terragrunt outputs; API server is unreachable from an IP not in `authorized_ip_ranges`.

### Implementation

- [x] T006 [US1] Rewrite `modules/azure-aks/main.tf`: replace `private_cluster_enabled = true`, `private_cluster_public_fqdn_enabled = false`, `dns_prefix_private_cluster`, `private_dns_zone_id` with `dns_prefix = "${var.project}-${var.environment}"`; add `api_server_access_profile { authorized_ip_ranges = var.api_server_authorized_ip_ranges }` block (v3.x location — NOT top-level `api_server_authorized_ip_ranges` which is removed in v4); remove `vnet_subnet_id` from `default_node_pool`; change `network_plugin` to `"kubenet"` (simpler without customer VNet — no subnet delegation); add `azurerm_public_ip` resource named `${var.project}-${var.environment}-pip-aks-outbound` with `allocation_method = "Static"`, `sku = "Standard"`; set `network_profile.load_balancer_profile.outbound_ip_address_ids = [azurerm_public_ip.aks_outbound.id]`
- [x] T007 [US1] Update `modules/azure-aks/variables.tf`: add `api_server_authorized_ip_ranges` variable (`type = list(string)`, no default — operator must supply); remove `vnet_id`, `aks_subnet_id`, `aks_private_dns_zone_id` variables (deleted from module)
- [x] T008 [US1] Update `modules/azure-aks/outputs.tf`: add `aks_outbound_ip` output (`value = azurerm_public_ip.aks_outbound.ip_address`, description explaining it is used by the postgresql module firewall rule); retain `aks_cluster_name`, `aks_cluster_id`, `oidc_issuer_url`, `eso_identity_client_id`, `eso_identity_principal_id`
- [x] T009 [US1] Rewrite `environments/dev/aks/terragrunt.hcl`: remove `dependency "vnet"` block entirely; remove `vnet_id`, `aks_subnet_id`, `aks_private_dns_zone_id` from `inputs`; add `api_server_authorized_ip_ranges = ["<operator-cidr>/32"]` placeholder comment instructing operator to set their IP; retain `dependency "resource_group"`, `node_count = 1`, `environment = "dev"`, `owner = "justin-mckenzie"`
- [x] T010 [P] [US1] Rewrite `environments/staging/aks/terragrunt.hcl` mirroring dev: remove `dependency "vnet"` and VNet inputs; add `api_server_authorized_ip_ranges`; `node_count = 3`, `environment = "staging"`
- [x] T011 [P] [US1] Rewrite `environments/production/aks/terragrunt.hcl` mirroring staging: `environment = "production"`, `node_count = 3`

**Checkpoint**: `terragrunt validate` passes on `modules/azure-aks/`; dev AKS root ready to apply.

---

## Phase 4: User Story 2a — Provision PostgreSQL Database (Priority: P1)

**Goal**: PostgreSQL Flexible Server with a public endpoint restricted by an AKS outbound IP
firewall rule; pre-seeded with `temporal` and `temporal_visibility` databases. Depends on Phase 3
(AKS) completing so the `aks_outbound_ip` output is available for the firewall rule.

**Independent Test**: `terragrunt apply` in `environments/dev/postgresql/` completes; server is in
Running state; both databases exist; connection on port 5432 succeeds from the AKS outbound IP;
connection is refused from any other IP.

### Implementation

- [x] T012 [US2] Rewrite `modules/azure-postgresql/main.tf`: remove `delegated_subnet_id`, `private_dns_zone_id`, `depends_on` DNS zone reference; set `public_network_access_enabled = true`; add `azurerm_postgresql_flexible_server_firewall_rule` resource named `"allow-aks-outbound"` with `server_id = azurerm_postgresql_flexible_server.this.id`, `start_ip_address = var.aks_outbound_ip`, `end_ip_address = var.aks_outbound_ip` (firewall rule requires IPv4 strings — NOT CIDR notation); retain `temporal` and `temporal_visibility` databases with `lifecycle { prevent_destroy = true }`; retain all server configurations (`max_connections = "300"`, `shared_preload_libraries = "pg_stat_statements"`, `azure.extensions = "PG_STAT_STATEMENTS"`)
- [x] T013 [US2] Update `modules/azure-postgresql/variables.tf`: remove `postgres_delegated_subnet_id`, `postgres_private_dns_zone_id`; add `aks_outbound_ip` variable (`type = string`, description: "AKS cluster outbound public IP address; used for PostgreSQL firewall rule. Sourced from the aks module aks_outbound_ip output.")
- [x] T014 [US2] Update `modules/azure-postgresql/outputs.tf`: remove any private-endpoint-related outputs (none present — file is clean); verify `postgresql_server_fqdn`, `postgresql_server_id`, `temporal_database_name`, `temporal_visibility_database_name` are present
- [x] T015 [US2] Rewrite `environments/dev/postgresql/terragrunt.hcl`: remove `dependency "vnet"` block; remove `postgres_delegated_subnet_id`, `postgres_private_dns_zone_id` from `inputs`; add `dependency "aks"` on `../aks`; add `aks_outbound_ip = dependency.aks.outputs.aks_outbound_ip` to `inputs`; retain `dependency "resource_group"`, `environment = "dev"`, `pg_admin_password` comment
- [x] T016 [P] [US2] Rewrite `environments/staging/postgresql/terragrunt.hcl`: remove VNet dependency and inputs; add `dependency "aks"`; add `aks_outbound_ip` from aks outputs; `environment = "staging"`, `sku_name = "GP_Standard_D2ds_v5"`, `storage_mb = 65536`
- [x] T017 [P] [US2] Rewrite `environments/production/postgresql/terragrunt.hcl`: same pattern; `environment = "production"`, `sku_name = "GP_Standard_D4ds_v5"`, `storage_mb = 131072`

**Checkpoint**: `terragrunt validate` passes on `modules/azure-postgresql/`; dev PostgreSQL root ready to apply.

---

## Phase 5: User Story 2b — Key Vault Module (Priority: P1)

**Goal**: Key Vault with a public endpoint and RBAC-only access (no network firewall). PostgreSQL
credentials stored as secrets; ESO Workload Identity RBAC wired up. Depends on Phase 3 (AKS)
for the ESO UAMI `principal_id`.

**Independent Test**: `terragrunt apply` in `environments/dev/key-vault/` completes; `key_vault_uri`
appears in outputs; `pg-admin-password` and `pg-admin-username` secrets exist in vault; ESO UAMI
principal has `Key Vault Secrets User` role on the vault.

### Implementation

- [x] T018 [US2] Rewrite `modules/azure-key-vault/main.tf`: remove `azurerm_private_endpoint` and `azurerm_private_dns_zone_group` resources; change `public_network_access_enabled = false` to `true`; add explicit `network_acls { default_action = "Allow"; bypass = "AzureServices" }` block (cannot be removed after creation per provider issue #27609 — must be explicit from the start); add `#tfsec:ignore:azure-keyvault-specify-network-acl` comment on the `azurerm_key_vault` resource block (tfsec flags open ACL as a finding; this is intentional); retain RBAC role assignments and secrets with `depends_on` the Secrets Officer assignment
- [x] T019 [US2] Update `modules/azure-key-vault/variables.tf`: remove `private_endpoints_subnet_id`, `keyvault_private_dns_zone_id` variables; all remaining variables (`project`, `environment`, `location`, `owner`, `resource_group_name`, `eso_identity_principal_id`, `pg_admin_password`, `pg_admin_username`, `purge_protection_enabled`, `soft_delete_retention_days`) are unchanged
- [x] T020 [US2] Rewrite `environments/dev/key-vault/terragrunt.hcl`: remove `dependency "vnet"` block; remove `private_endpoints_subnet_id`, `keyvault_private_dns_zone_id` from `inputs`; retain `dependency "resource_group"`, `dependency "aks"`; retain `eso_identity_principal_id = dependency.aks.outputs.eso_identity_principal_id`, `purge_protection_enabled = false`, `soft_delete_retention_days = 7`, `pg_admin_password` comment
- [x] T021 [P] [US2] Rewrite `environments/staging/key-vault/terragrunt.hcl`: remove VNet dependency and inputs; retain `dependency "aks"`; `environment = "staging"`, `purge_protection_enabled = true`, `soft_delete_retention_days = 90`
- [x] T022 [P] [US2] Rewrite `environments/production/key-vault/terragrunt.hcl`: same pattern; `environment = "production"`, `purge_protection_enabled = true`, `soft_delete_retention_days = 90`

**Checkpoint**: `terragrunt validate` passes on `modules/azure-key-vault/`; dev Key Vault root ready to apply.

---

## Phase 6: User Story 3 — Infrastructure Lifecycle Management (Priority: P2)

**Goal**: Validate all three modules are idempotent across all three environments; confirm
`terragrunt plan` after a clean apply shows zero changes.

**Independent Test**: `terragrunt plan` on each of the 9 environment roots (3 envs × 3 modules)
after a clean `apply` produces zero planned changes.

### Implementation

- [x] T023 [US3] Verify all 9 `terragrunt.hcl` environment roots (`dev/aks`, `dev/postgresql`, `dev/key-vault`, `staging/*`, `production/*`) have no remaining references to `dependency "vnet"` or stale VNet input variables; run `grep -r "dependency.*vnet\|vnet_id\|aks_subnet_id\|private_dns_zone" environments/` and confirm zero matches
- [x] T024 [US3] Verify `modules/azure-aks/main.tf` contains no references to `private_cluster_enabled`, `dns_prefix_private_cluster`, `private_dns_zone_id`, `vnet_subnet_id`; run `grep -n "private_cluster\|dns_prefix_private\|vnet_subnet_id" modules/azure-aks/main.tf` and confirm zero matches
- [x] T025 [US3] Verify `modules/azure-postgresql/main.tf` contains no references to `delegated_subnet_id`, `private_dns_zone_id`, `public_network_access_enabled = false`; run `grep -n "delegated_subnet\|private_dns_zone\|public_network_access_enabled.*false" modules/azure-postgresql/main.tf` and confirm zero matches
- [x] T026 [US3] Verify `modules/azure-key-vault/main.tf` contains no `azurerm_private_endpoint` or `azurerm_private_dns_zone_group` resources; run `grep -n "private_endpoint\|private_dns_zone_group" modules/azure-key-vault/main.tf` and confirm zero matches
- [x] T027 [P] [US3] Run `terragrunt validate` on `modules/azure-aks/`, `modules/azure-postgresql/`, `modules/azure-key-vault/` and fix any provider schema validation errors

**Checkpoint**: All modules validate cleanly; zero stale private-networking references remain.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Update documentation files that were pre-written for the old private-networking
architecture; run policy checks; confirm changelog is accurate.

- [x] T028 Update `CHANGELOG.md` `[Unreleased]` section: replace the 5-module entry (which includes `azure-vnet`, `azure-vpn-gateway`, "VNet injection", "private API server") with a 3-module entry reflecting the actual public-endpoint design: `azure-aks` (public cluster with `authorized_ip_ranges`, pre-allocated static outbound IP, Workload Identity); `azure-postgresql` (public endpoint, AKS outbound IP firewall rule, Temporal databases pre-seeded); `azure-key-vault` (public endpoint, RBAC-only, PostgreSQL credentials); update the `policies/naming.rego` bullet to remove `azurerm_virtual_network_gateway` from the list; remove `azure-vnet` and `azure-vpn-gateway` lines entirely
- [x] T029 Update `CONTRIBUTING.md` Pre-Deployment Checklist section (lines 74–141): remove Step 1 (VPN P2S root certificate generation — no VPN Gateway); remove `TF_VAR_vpn_root_certificate_pem` from Step 2 environment variables; update Step 4 apply order to remove `vnet` and `vpn-gateway` steps (new order: `resource-group` → `aks` → `postgresql` + `key-vault` in parallel); add a new step for setting `api_server_authorized_ip_ranges` in each environment's `aks/terragrunt.hcl` inputs before applying; update Key Vault immutable settings table to remove VPN-related footnotes if any
- [x] T030 [P] Run `tfsec` and `checkov` locally on `modules/azure-aks/`, `modules/azure-postgresql/`, `modules/azure-key-vault/`; remediate any HIGH/CRITICAL findings per constitution Principle VI CI gate; the `azure-keyvault-specify-network-acl` tfsec finding on Key Vault is expected — confirm it is suppressed via `#tfsec:ignore` comment added in T018
- [x] T031 [P] Update `CLAUDE.md` Active Technologies section: remove references to `azure-vnet` and `azure-vpn-gateway` modules and their resource types (`azurerm_virtual_network`, `azurerm_subnet`, `azurerm_network_security_group`, `azurerm_virtual_network_gateway`); add note that feature 003 uses public endpoints with IP-based access restriction

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all module work
- **Phase 3 (AKS)**: Depends on Phase 2
- **Phase 4 (PostgreSQL)**: Depends on Phase 3 (AKS outbound IP output)
- **Phase 5 (Key Vault)**: Depends on Phase 3 (AKS ESO UAMI principal_id output); can run in parallel with Phase 4
- **Phase 6 (Lifecycle validation)**: Depends on Phases 3–5
- **Polish (Phase 7)**: Depends on Phases 3–6

### User Story Dependencies

- **US1 (AKS)**: Depends on Foundational (Phase 2) only
- **US2 (PostgreSQL + Key Vault)**: PostgreSQL depends on US1 (aks_outbound_ip); Key Vault depends on US1 (eso_identity_principal_id)
- **US3 (Lifecycle)**: Depends on US1 + US2 being complete

### Parallel Opportunities

- T001, T002, T003 (Phase 1 cleanup) — can run in parallel
- T010, T011 (staging/production AKS roots) — parallel after T009
- T016, T017 (staging/production PostgreSQL roots) — parallel after T015
- T021, T022 (staging/production Key Vault roots) — parallel after T020
- T023–T027 (Phase 6 verification tasks) — all parallel
- T028, T029, T030, T031 (Phase 7 polish) — all parallel

### Terraform Apply Order (dev environment)

```
1. resource-group  (existing, no change)
2. aks             (Phase 3) — produces aks_outbound_ip + eso_identity_principal_id
3. postgresql      (Phase 4)  ← parallel with key-vault once aks outputs are available
   key-vault       (Phase 5)  ← parallel with postgresql
```

Use `terragrunt run-all apply` from `environments/dev/` — Terragrunt resolves the dependency
graph automatically.

---

## Parallel Example: User Story 2 (PostgreSQL + Key Vault)

```text
# After Phase 3 (AKS) completes and outputs are available:

# These can run in parallel (different modules, independent files):
T012 — rewrite modules/azure-postgresql/main.tf
T018 — rewrite modules/azure-key-vault/main.tf

# Then, once module files are updated:
T015 — rewrite environments/dev/postgresql/terragrunt.hcl
T020 — rewrite environments/dev/key-vault/terragrunt.hcl

# Then staging/production in parallel:
T016, T017 — postgresql staging + production roots
T021, T022 — key-vault staging + production roots
```

---

## Implementation Strategy

### MVP First (AKS cluster only)

1. Complete Phase 1: Setup (stale artifact cleanup)
2. Complete Phase 2: Foundational (policy verification)
3. Complete Phase 3: AKS module rework + dev environment root
4. **STOP and VALIDATE**: `terragrunt apply` dev/aks; confirm 1 Ready node; confirm API server
   is accessible only from authorized CIDR; confirm `aks_outbound_ip` output is present
5. Continue with Phase 4 + 5 in parallel

### Incremental Delivery

1. Phase 1 + 2 → stale artifacts removed, policy correct
2. Phase 3 (AKS) → compute layer confirmed
3. Phase 4 + 5 (PostgreSQL + Key Vault, parallel) → database and secrets management ready
4. Phase 6 (Lifecycle) → idempotency validated
5. Phase 7 (Polish) → documentation aligned with implemented architecture

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks in same phase
- [Story] label maps each task to its user story for traceability
- `soft_delete_retention_days` and `purge_protection_enabled` on Key Vault are immutable after
  first apply — dev=`false`/`7`, staging+production=`true`/`90` — verify before first apply
- `prevent_destroy = true` on PostgreSQL databases means `terraform destroy` will fail unless
  lifecycle is temporarily removed — this is intentional and expected
- The `azurerm_public_ip` for AKS outbound (T006) must be created in the same `apply` as the
  AKS cluster; both are in `modules/azure-aks/main.tf` so they apply together automatically
- `api_server_authorized_ip_ranges` requires IPv4 CIDR notation (e.g., `"203.0.113.1/32"`)
  not bare IP addresses — the provider validates this
