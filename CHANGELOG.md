# Changelog

All notable changes to homeschoolio-infra are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- `modules/azure-aks` v1.0.0 — Public AKS cluster with `authorized_ip_ranges` restricting API
  server access; pre-allocated static outbound public IP for deterministic PostgreSQL firewall rules;
  kubenet network plugin; Workload Identity enabled with ESO user-assigned managed identity and
  federated identity credential
- `modules/azure-postgresql` v1.0.0 — PostgreSQL Flexible Server with public endpoint restricted to
  AKS outbound IP via firewall rule; pre-seeded with `temporal` and `temporal_visibility` databases;
  max_connections and pg_stat_statements tuned for Temporal workloads
- `modules/azure-key-vault` v1.0.0 — Key Vault in RBAC mode with public endpoint and no
  network-level firewall; PostgreSQL credentials stored as secrets; ESO UAMI granted Key Vault
  Secrets User role
- Terragrunt roots for `dev`, `staging`, and `production` environments for `aks`, `postgresql`,
  and `key-vault` modules
- Extended `policies/naming.rego` enforced_types with `azurerm_postgresql_flexible_server`,
  `azurerm_user_assigned_identity`, `azurerm_public_ip`

- `modules/azure-resource-group` v1.0.0 — OpenTofu module that provisions a tagged Azure resource
  group (`{project}-{environment}-rg-main`) with required `Project`, `Environment`, `ManagedBy`,
  and `Owner` tags; satisfies OPA naming and tag policies
- Terragrunt roots for `dev`, `staging`, and `production` environments under
  `environments/{env}/resource-group/`

### Removed

- `modules/example/` — CI/CD validation scaffold; superseded by `modules/azure-resource-group/`
- `environments/{env}/infra/` Terragrunt roots that sourced the example module

---

## [1.0.0] — 2026-03-26

### Added

- CI/CD pipeline infrastructure for OpenTofu/Terragrunt on Microsoft Azure
  - `ci.yml` — PR trigger workflow: validate → test → plan → destructive-op gate
  - `cd.yml` — Merge promotion workflow: dev (auto) → staging → production (env gates)
  - `release.yml` — Semantic version release via conventional commits
- Shared reusable workflows published to `jmckenzie17/homeschoolio-shared-actions@v1.0.0`
  - `validate.yml` — HCL format check + OpenTofu validation with provider caching
  - `test.yml` — tfsec (static HCL), Checkov (plan JSON), OPA/Conftest (custom policies)
  - `plan.yml` — Changed-root detection, plan generation, PR comment, artifact upload
  - `apply.yml` — Pre-apply verification + `terragrunt run-all apply` with Azure OIDC
- OPA/Conftest policies in `policies/`
  - `tags.rego` — Required tag enforcement: `Project`, `Environment`, `ManagedBy`, `Owner`
  - `naming.rego` — Naming convention: `{project}-{environment}-{resource-type}-{descriptor}`
- `CONTRIBUTING.md` with conventional commit guidelines and version bump reference table
- Repository tooling: `.opentofu-version` (1.6.2), `.terragrunt-version` (0.56.3), `.gitignore`

---

<!-- Module versions are tracked separately as Git tags: modules/{name}/{version} -->
