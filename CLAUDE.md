# homeschoolio-infra Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-27

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
- 002-azure-resource-group: Added HCL (OpenTofu 1.6.2, pinned via `.opentofu-version`) + Terragrunt 0.56.3 (pinned via `.terragrunt-version`); AzureRM provider `~> 3.0`
- 002-azure-resource-group: Added HCL (OpenTofu 1.6.2, pinned via `.opentofu-version`) + Terragrunt 0.56.3 (pinned via `.terragrunt-version`); AzureRM provider `~> 3.0`
- 001-terraform-cicd-pipelines: Added HCL (OpenTofu 1.6.2) + Terragrunt 0.56.3 (pinned via `.opentofu-version` / `.terragrunt-version`) + `opentofu/setup-opentofu@v1`, `actions/cache@v4`, `jmckenzie17/homeschoolio-shared-actions@v1.3.2` (validate, plan, test, apply, semver-release shared workflows)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
