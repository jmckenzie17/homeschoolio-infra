# Quickstart: Azure Resource Group

**Feature**: 002-azure-resource-group

## Prerequisites

- OpenTofu 1.6.2 (`cat .opentofu-version`)
- Terragrunt 0.56.3 (`cat .terragrunt-version`)
- Azure credentials with permission to create resource groups (OIDC or `az login`)
- The remote state storage account `homeschooliostfstate` must already exist

## Deploying (Dev)

```bash
cd environments/dev/resource-group
terragrunt plan     # Review the plan — expect 1 resource to add
terragrunt apply    # Creates homeschoolio-dev-rg-main in eastus
```

## Deploying All Environments

Follow the promotion path (constitution Principle II): dev → staging → production.

```bash
# 1. Dev
cd environments/dev/resource-group && terragrunt apply

# 2. Staging (after dev succeeds)
cd environments/staging/resource-group && terragrunt apply

# 3. Production (after staging succeeds — requires PR review + environment gate)
cd environments/production/resource-group && terragrunt apply
```

## Verifying

After apply, confirm the resource group exists:

```bash
az group show --name homeschoolio-dev-rg-main
```

Expected output includes:
- `"location": "eastus"`
- `"tags": { "Project": "homeschoolio", "Environment": "dev", "ManagedBy": "opentofu", "Owner": "justin-mckenzie" }`

## Idempotency Check

```bash
terragrunt plan   # Should show: No changes. Your infrastructure matches the configuration.
```

## Destroying

```bash
cd environments/dev/resource-group
terragrunt destroy   # Removes homeschoolio-dev-rg-main
```

> Note: If the resource group contains child resources, the destroy will remove them all. Verify the group is empty before running in staging or production.

## Module Location

```
modules/azure-resource-group/
├── main.tf        # azurerm_resource_group resource + provider config
├── variables.tf   # project, environment, location, owner
├── outputs.tf     # resource_group_name, resource_group_id
└── version.tf     # module_version = "1.0.0"
```

## Terragrunt Roots

```
environments/
├── dev/resource-group/terragrunt.hcl
├── staging/resource-group/terragrunt.hcl
└── production/resource-group/terragrunt.hcl
```
