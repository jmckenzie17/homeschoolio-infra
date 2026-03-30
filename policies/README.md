# OPA/Conftest Policies

These Rego policies run during the CI `test` stage against the Terraform plan JSON output (`tfplan.json`). All policies share the `main` package so Conftest evaluates them together.

---

## tags.rego

**What it enforces:** Every Azure resource being created or updated must carry all four required tags. Resources being deleted and data sources are exempt.

Required tags: `Project`, `Environment`, `ManagedBy`, `Owner`

**Error message format:**

```
Resource <address> (<type>) is missing required tag: <tag>
```

**Example violation:**

```hcl
resource "azurerm_resource_group" "example" {
  name     = "homeschoolio-dev-rg-example"
  location = "eastus"

  tags = {
    Project     = "homeschoolio"
    Environment = "dev"
    ManagedBy   = "terraform"
    # Owner tag is absent
  }
}
```

CI output:

```
FAIL - tfplan.json - main - Resource azurerm_resource_group.example (azurerm_resource_group) is missing required tag: Owner
```

**Example passing:**

```hcl
resource "azurerm_resource_group" "example" {
  name     = "homeschoolio-dev-rg-example"
  location = "eastus"

  tags = {
    Project     = "homeschoolio"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}
```

---

## naming.rego

**What it enforces:** The `name` attribute of enforced resource types must follow the convention `{project}-{environment}-{resource-type}-{descriptor}` — four or more hyphen-separated lowercase alphanumeric segments.

Pattern: `^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+-[a-z0-9][a-z0-9-]*$`

Example of a compliant name: `homeschoolio-dev-rg-example`

Resources being deleted and data sources are exempt. Resource types not in the list below are not evaluated.

**Enforced resource types:**

- `azurerm_resource_group`
- `azurerm_virtual_network`
- `azurerm_subnet`
- `azurerm_network_security_group`
- `azurerm_storage_account`
- `azurerm_key_vault`
- `azurerm_container_registry`
- `azurerm_kubernetes_cluster`
- `azurerm_linux_virtual_machine`
- `azurerm_app_service`
- `azurerm_function_app`

**Error message format:**

```
Resource <address> has name "<name>" which does not match required convention {project}-{environment}-{type}-{descriptor}
```

**Example violation:**

```hcl
resource "azurerm_resource_group" "bad" {
  name     = "my-rg"   # only two segments
  location = "eastus"
  tags     = { ... }
}
```

CI output:

```
FAIL - tfplan.json - main - Resource azurerm_resource_group.bad has name "my-rg" which does not match required convention {project}-{environment}-{type}-{descriptor}
```

**Example passing:**

```hcl
resource "azurerm_resource_group" "example" {
  name     = "homeschoolio-dev-rg-example"
  location = "eastus"
  tags     = { ... }
}
```

---

## Running Conftest locally

Generate a plan JSON from the relevant Terragrunt root, then run Conftest:

```bash
terragrunt plan -out=tfplan.binary
terragrunt show -json tfplan.binary > tfplan.json
conftest test tfplan.json -p policies/ --all-namespaces
```

A clean run exits 0. Failures print each violated rule with the resource address.

---

## Adding a new policy

1. Create `policies/<name>.rego` with `package main` at the top.
2. Define one or more `deny contains msg if { ... }` rules. Conftest collects all `deny` results across files automatically.
3. Add a test file `policies/<name>_test.rego` with at least one passing and one failing fixture.
4. Run locally with the command above before opening a PR.

To extend the naming convention to a new resource type, add its provider type string to the `enforced_types` set in `naming.rego`.
