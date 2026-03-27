# Data Model: Azure Resource Group

**Feature**: 002-azure-resource-group

## Entities

### Resource Group (`azurerm_resource_group`)

The single Azure resource managed by this module.

| Attribute | Type | Value / Source | Notes |
|-----------|------|----------------|-------|
| `name` | string | `homeschoolio-{environment}-rg-main` | OPA naming policy requires 4 segments |
| `location` | string | `var.location` (default: `eastus`) | Configurable via Terragrunt input |
| `tags.Project` | string | `var.project` (default: `homeschoolio`) | Required by OPA tags policy |
| `tags.Environment` | string | `var.environment` | Required by OPA tags policy |
| `tags.ManagedBy` | string | `"opentofu"` | Required by OPA tags policy; literal constant |
| `tags.Owner` | string | `var.owner` (default: `justin-mckenzie`) | Required by OPA tags policy |

### Module Outputs

| Output | Type | Description |
|--------|------|-------------|
| `resource_group_name` | string | Name of the created resource group — consumed by downstream modules |
| `resource_group_id` | string | Azure resource ID of the group — used for role assignments and dependency linking |

### Module Inputs (Variables)

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `project` | string | `"homeschoolio"` | No | Project name for naming and tagging; injected by root terragrunt.hcl |
| `environment` | string | — | Yes | Environment tier; injected from path by root terragrunt.hcl |
| `location` | string | `"eastus"` | No | Azure region; injected by root terragrunt.hcl |
| `owner` | string | `"justin-mckenzie"` | No | Owner tag value |

## State

This module has no internal state transitions. The resource group is either present or absent. Idempotent: re-applying with identical inputs produces a no-op plan.

## Relationships

The resource group created by this module is intended to be the **parent container** for future homeschoolio application resources (networking, compute, storage). Downstream modules will reference `resource_group_name` or `resource_group_id` outputs via Terragrunt dependency blocks.

```
resource-group module
  └── azurerm_resource_group.this
        └── (future) networking module
        └── (future) compute module
        └── (future) storage module
```
