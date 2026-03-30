# homeschoolio-infra Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-30

## Active Technologies
- Azure Storage Account + Blob container per Terragrunt root (per (001-terraform-cicd-pipelines)
- HCL (OpenTofu ≥ 1.6) + Terragrunt ≥ 0.56 + `opentofu/setup-opentofu@v1`, `actions/cache@v4`, `tj-actions/changed-files@v44`, `cycjimmy/semantic-release-action@v6` (via shared workflow), tfsec, Checkov, OPA/Conftes (001-terraform-cicd-pipelines)
- Azure Storage Account + Blob container per Terragrunt root (per constitution Principle V) (001-terraform-cicd-pipelines)
- Azure Storage Account `homeschooliostfstate` + Blob containers per environment (`homeschoolio-{env}-infra-tfstate`); resource group `homeschoolio-shared-rg-tfstate` (001-terraform-cicd-pipelines)
- HCL (OpenTofu ≥ 1.6) + Terragrunt ≥ 0.56 + `opentofu/setup-opentofu@v1`, `actions/cache@v4`, tfsec, Checkov, Conftest, semantic-release (001-terraform-cicd-pipelines)
- Azure Storage Account `homeschooliostfstate` (eastus) — containers: `homeschoolio-dev-infra-tfstate`, `homeschoolio-staging-infra-tfstate`, `homeschoolio-production-infra-tfstate` (001-terraform-cicd-pipelines)
- HCL (OpenTofu 1.6.2) + Terragrunt 0.56.3 (pinned via `.opentofu-version` / `.terragrunt-version`) + `opentofu/setup-opentofu@v1`, `actions/cache@v4`, `jmckenzie17/homeschoolio-shared-actions@v1.3.2` (validate, plan, test, apply, semver-release shared workflows) (001-terraform-cicd-pipelines)
- Azure Storage Account `homeschooliostfstate` (eastus) — containers `homeschoolio-{env}-infra-tfstate` per Terragrunt root; Azure Blob lease locking (001-terraform-cicd-pipelines)
- HCL (OpenTofu 1.6.2, pinned via `.opentofu-version`) + Terragrunt 0.56.3 (pinned via `.terragrunt-version`); AzureRM provider `~> 3.0` (002-azure-resource-group)
- Azure Blob Storage (`homeschooliostfstate`) — remote state backend; no application storage (002-azure-resource-group)
- HCL (OpenTofu 1.6.2, pinned via `.opentofu-version`) + Terragrunt 0.56.3 (pinned via `.terragrunt-version`); AzureRM provider `~> 3.0` (≥ 3.28 required for `workload_identity_enabled`, ≥ 3.27 required for `public_network_access_enabled`) (003-azure-temporal-infra)
- Azure Blob Storage (`homeschooliostfstate`) — remote state only; PostgreSQL Flexible Server — Temporal workflow state; public endpoints with IP-based access restriction (003-azure-temporal-infra)

- HCL (OpenTofu ≥ 1.6) + Terragrunt ≥ 0.56 + `opentofu/setup-opentofu@v1`, `actions/cache@v4`, (001-terraform-cicd-pipelines)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for HCL (OpenTofu ≥ 1.6) + Terragrunt ≥ 0.56

## Code Style

HCL (OpenTofu ≥ 1.6) + Terragrunt ≥ 0.56: Follow standard conventions

## Recent Changes
- 003-azure-temporal-infra: Added public AKS cluster (`authorized_ip_ranges`, static outbound IP, kubenet, Workload Identity), PostgreSQL Flexible Server (public endpoint, AKS outbound IP firewall rule, Temporal databases), Key Vault (RBAC mode, public endpoint, PostgreSQL credentials); removed VNet, VPN Gateway, and private endpoint architecture


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
