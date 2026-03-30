# Contributing

## Conventional Commits

This repository uses [Conventional Commits](https://www.conventionalcommits.org/) to drive
automatic semantic version releases. Every commit merged to `main` must follow this format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types and Version Bumps

| Type | Version Bump | When to Use |
|------|-------------|-------------|
| `feat:` | **minor** (1.x.0) | New module, new resource type, new environment support |
| `fix:` | **patch** (1.0.x) | Bug fix in a module, corrected resource configuration |
| `BREAKING CHANGE` footer | **major** (x.0.0) | Removed output, changed required variable, incompatible state migration |
| `chore:` | none | Dependency updates, CI config, tooling |
| `docs:` | none | Documentation only changes |
| `style:` | none | Formatting, whitespace (no logic change) |
| `refactor:` | none | Code restructuring without behavior change |
| `test:` | none | Adding or updating policy tests |

### Examples for Infrastructure Changes

```
feat: add azure kubernetes cluster module

feat(networking): add private endpoint support to storage module

fix: correct subnet address prefix overlap in dev environment

fix(policy): add azurerm_key_vault to naming convention enforcement

chore: upgrade opentofu from 1.6.2 to 1.7.0

docs: add runbook for production rollback procedure

feat!: remove deprecated outputs from vpc module

BREAKING CHANGE: outputs `subnet_id` and `vnet_id` have been renamed to
`subnet_ids` (list) and `vnet_id`. Update all terragrunt.hcl source references.
```

### Breaking Changes

For breaking changes, use either:

1. `!` after the type: `feat!: rename all module outputs`
2. `BREAKING CHANGE:` footer in the commit body:
   ```
   feat: consolidate networking modules

   BREAKING CHANGE: the `homeschoolio-networking` module has been split into
   `homeschoolio-vnet` and `homeschoolio-subnet`. Update source references accordingly.
   ```

### Release Behavior

The CI/CD pipeline runs `semantic-release` on every merge to `main`. It:

1. Analyzes commit messages since the last release tag
2. Creates a `v{MAJOR.MINOR.PATCH}` tag if qualifying commits are found
3. Updates the floating `v{MAJOR}` pointer tag
4. Generates a changelog entry

No tag is created for `chore:`, `docs:`, `style:`, `refactor:`, or `test:` commits alone.

## Pre-Deployment Checklist: Feature 003 (Azure Temporal Infrastructure)

Before running `terragrunt apply` for the first time in any environment, complete the following steps:

### 1. Set `api_server_authorized_ip_ranges`

Before applying the AKS module, set your operator CIDR in `environments/<env>/aks/terragrunt.hcl`:

```hcl
api_server_authorized_ip_ranges = ["<your-public-ip>/32"]
```

The placeholder value `["0.0.0.0/0"]` allows all sources and is not appropriate for production.
To find your current public IP: `curl -s https://checkip.amazonaws.com`

### 2. Set Required Environment Variables

```bash
# PostgreSQL administrator password (required by postgresql and key-vault modules)
export TF_VAR_pg_admin_password="<secure-random-password>"
```

### 3. Confirm ESO ServiceAccount Coordinates

The AKS module's federated identity credential subject is:
```
system:serviceaccount:<eso_namespace>:<eso_service_account_name>
```
Defaults: `external-secrets` / `external-secrets`.

If the External Secrets Operator deployment uses different values, override in the environment's
`aks/terragrunt.hcl` `inputs` block before applying.

### 4. Apply Order

Apply modules in this order (Terragrunt resolves automatically with `run-all apply`):

```
1. resource-group  (existing — no change required)
2. aks             (produces outbound IP and ESO UAMI outputs)
3. postgresql + key-vault  (parallel — both depend only on aks outputs)
```

### 5. Key Vault Immutable Settings

The following settings are **immutable after first apply** — verify before provisioning:

| Environment | `purge_protection_enabled` | `soft_delete_retention_days` |
|-------------|---------------------------|------------------------------|
| dev         | `false`                   | `7`                          |
| staging     | `true`                    | `90`                         |
| production  | `true`                    | `90`                         |

---

### Pull Request Guidelines

- PR title should follow the same conventional commit format
- One logical change per PR when possible
- For infrastructure changes that include destructive operations (resource deletions or
  replacements), add the following checkbox to the PR description:
  ```
  - [x] I acknowledge destructive operations in this plan
  ```
  The merge gate will be blocked until this acknowledgment is present.
