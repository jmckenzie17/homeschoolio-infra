# OPA/Conftest Policies

This directory contains OPA (Open Policy Agent) Rego policies evaluated by Conftest
against OpenTofu plan JSON during the CI `test` stage.

## How Policies Are Evaluated

Policies run via:
```sh
conftest test tfplan.json -p policies/ --all-namespaces --output github --no-color
```

Failures produce GitHub annotations identifying the exact resource address and violated rule.

---

## `tags.rego` — Required Azure Tag Compliance

**Package**: `main`

**What it enforces**: Every Azure resource being created or updated must carry all four
required tags: `Project`, `Environment`, `ManagedBy`, and `Owner`.

**Resources checked**: All `resource_changes` entries whose action is not `no-op`, `delete`,
or a data source (`data.`).

**Failure message format**:
```
Resource {address} ({type}) is missing required tag: {tag}
```

**Example violation**:
```
Resource azurerm_resource_group.example (azurerm_resource_group) is missing required tag: Owner
```

**How to fix**: Add all four required tags to the resource:
```hcl
resource "azurerm_resource_group" "example" {
  name     = "homeschoolio-dev-rg-example"
  location = "eastus"
  tags = {
    Project     = "homeschoolio"
    Environment = "dev"
    ManagedBy   = "opentofu"
    Owner       = "platform-team"
  }
}
```

---

## `naming.rego` — Azure Resource Naming Convention

**Package**: `naming`

**What it enforces**: Enforced Azure resource types must follow the naming pattern:
```
{project}-{environment}-{resource-type}-{descriptor}
```
All lowercase alphanumeric segments separated by hyphens.

**Pattern**: `^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+-[a-z0-9][a-z0-9-]*$`

**Enforced resource types**:
- `azurerm_resource_group`
- `azurerm_virtual_network`
- `azurerm_subnet`
- `azurerm_storage_account`
- `azurerm_key_vault`
- `azurerm_kubernetes_cluster`

**Failure message format**:
```
Resource {address} ({type}) name "{name}" does not match required pattern {project}-{env}-{type}-{descriptor}
```

**Example violation**:
```
Resource azurerm_resource_group.rg (azurerm_resource_group) name "myRG" does not match required pattern {project}-{env}-{type}-{descriptor}
```

**How to fix**: Rename to follow the convention:
```hcl
resource "azurerm_resource_group" "example" {
  name = "homeschoolio-dev-rg-example"
  # ...
}
```
