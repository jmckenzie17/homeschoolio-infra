# Implementation Plan: Azure Resource Group for Homeschoolio

**Branch**: `002-azure-resource-group` | **Date**: 2026-03-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-azure-resource-group/spec.md`

## Summary

Create a reusable OpenTofu module (`modules/azure-resource-group/`) that provisions a tagged Azure resource group, and wire it into Terragrunt roots for dev, staging, and production environments. The resource group will serve as the parent container for all future homeschoolio application resources. The implementation mirrors the existing `modules/example/` pattern exactly, correcting only the resource name to use the `main` descriptor rather than `example`.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6.2, pinned via `.opentofu-version`)
**Primary Dependencies**: Terragrunt 0.56.3 (pinned via `.terragrunt-version`); AzureRM provider `~> 3.0`
**Storage**: Azure Blob Storage (`homeschooliostfstate`) — remote state backend; no application storage
**Testing**: `terragrunt validate`, `terragrunt plan` (plan-as-artifact); tfsec, Checkov, Conftest (OPA) via CI
**Target Platform**: Microsoft Azure (eastus region)
**Project Type**: Infrastructure-as-code module + Terragrunt environment roots
**Performance Goals**: Plan execution < 30 seconds; apply < 2 minutes (Azure resource group creation is near-instant)
**Constraints**: Must satisfy OPA naming regex `^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+-[a-z0-9][a-z0-9-]*$`; must carry all four required tags (`Project`, `Environment`, `ManagedBy`, `Owner`)
**Scale/Scope**: 3 environments × 1 resource group each = 3 Azure resources total

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Gate | Status | Notes |
|-----------|------|--------|-------|
| I. Infrastructure as Code | All resources in `.tf` files; no manual changes | PASS | Module uses `azurerm_resource_group`; no manual steps |
| I. No secrets in source | No secrets required for a resource group | PASS | No Key Vault references needed |
| II. Environment parity | Module code identical across envs; only Terragrunt inputs differ | PASS | Single module, 3 roots with input-only differences |
| II. State isolation | Each env root has its own remote state key | PASS | Root `terragrunt.hcl` generates unique key per path |
| III. Immutable versioning | Module versioned at `1.0.0`; no floating refs | PASS | New module starts at `1.0.0` per constitution |
| III. CHANGELOG entry | Required on version bump | PASS | Entry present in `CHANGELOG.md` [Unreleased] section |
| IV. Plan before apply | Plan published as CI artifact; reviewed before apply | PASS | Existing CI pipeline handles this |
| IV. Destructive ops acknowledged | No replacements expected | PASS | Resource group creation is non-destructive |
| V. Remote state | Azure Blob backend; no local state | PASS | Inherits root `terragrunt.hcl` backend config |
| V. State locking | Azure Blob lease locking | PASS | Inherited from root config |
| VI. Lowest-cost SKU | Resource groups have no SKU/cost | PASS | No tier selection needed |
| VI. Policy-as-code | tfsec, Checkov, Conftest run in CI | PASS | Existing CI gates apply to all changed roots |
| VI. Audit logs | Deployments traceable to commit SHA via CI | PASS | Existing pipeline annotates applies with SHA |

**Post-design re-check**: All gates pass. No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/002-azure-resource-group/
├── plan.md          # This file
├── research.md      # Phase 0 output — decisions and unknowns resolved
├── data-model.md    # Phase 1 output — entities, variables, outputs
├── quickstart.md    # Phase 1 output — deploy/verify instructions
└── tasks.md         # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
modules/
└── azure-resource-group/
    ├── main.tf         # Provider config + azurerm_resource_group.this
    ├── variables.tf    # project, environment, location, owner
    ├── outputs.tf      # resource_group_name, resource_group_id
    └── version.tf      # module_version = "1.0.0"

environments/
├── dev/
│   └── resource-group/
│       └── terragrunt.hcl
├── staging/
│   └── resource-group/
│       └── terragrunt.hcl
└── production/
    └── resource-group/
        └── terragrunt.hcl
```

**Structure Decision**: Single module under `modules/azure-resource-group/` with three thin Terragrunt roots, one per environment. This follows the established `modules/example/` + `environments/{env}/infra/` pattern exactly. No new directories at the repo root are needed.

## Complexity Tracking

> No constitution violations — this table is intentionally empty.

## Implementation Details

### Module: `modules/azure-resource-group/`

**main.tf**
- Provider: `azurerm` with `use_oidc = true`, `skip_provider_registration = true` (mirrors example module)
- `required_version = ">= 1.6"`, `azurerm ~> 3.0`
- Resource: `azurerm_resource_group.this`
  - `name = "${var.project}-${var.environment}-rg-main"` → satisfies OPA 4-segment naming policy
  - `location = var.location`
  - Tags: `Project`, `Environment`, `ManagedBy = "opentofu"`, `Owner` → satisfies OPA tags policy

**variables.tf** — identical interface to `modules/example/`
- `project` (string, default `"homeschoolio"`)
- `environment` (string, required)
- `location` (string, default `"eastus"`)
- `owner` (string, default `"justin-mckenzie"`)

**outputs.tf**
- `resource_group_name` — consumed by downstream modules
- `resource_group_id` — used for role assignments and dependency blocks

**version.tf**
- `module_version = "1.0.0"`

### Terragrunt Roots

Each root follows the `environments/dev/infra/terragrunt.hcl` pattern exactly:

```hcl
include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
}

terraform {
  source = "${get_repo_root()}//modules/azure-resource-group"
}

inputs = {
  environment = "{env}"
}
```

The root `terragrunt.hcl` auto-injects `project`, `location` from locals and derives `environment` from the path. No additional inputs are needed.

### Key Design Notes

1. **Naming**: `homeschoolio-{env}-rg-main` — `main` is the descriptor per constitution convention; a 3-segment name like `homeschoolio-{env}-rg` would fail the OPA naming policy (`policies/naming.rego`).

2. **Tags**: Must use PascalCase keys (`Project`, `Environment`, `ManagedBy`, `Owner`) as enforced by `policies/tags.rego`. FR-003 in spec.md uses incorrect lowercase/kebab casing — the Assumptions section and this plan are authoritative.

3. **State key**: Will resolve to `environments/{env}/resource-group/terraform.tfstate` within the `homeschoolio-{env}-infra-tfstate` container. Unique; no collision with the existing `infra` root state.

4. **No new containers**: The existing per-environment blob containers are reused. No Terraform/manual provisioning of new containers is required.

5. **CHANGELOG**: A `1.0.0` entry is present in `CHANGELOG.md` [Unreleased] section for the new module per constitution Principle III.
