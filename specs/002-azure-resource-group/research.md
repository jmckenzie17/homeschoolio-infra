# Research: Azure Resource Group for Homeschoolio

**Phase**: 0 — Research & Unknowns Resolution
**Feature**: 002-azure-resource-group

## Decision Log

### 1. Module Naming & Location

**Decision**: `modules/azure-resource-group/`

**Rationale**: The repo already has `modules/example/` as the established pattern. Using a descriptive hyphenated name matching the Azure resource type is consistent with the repo's conventions and the constitution's module structure mandate.

**Alternatives considered**: `modules/rg/` (too terse, breaks discoverability)

---

### 2. Resource Group Name

**Decision**: `homeschoolio-{environment}-rg-main`

**Rationale**: The OPA naming policy (`policies/naming.rego`) enforces the regex `^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+-[a-z0-9][a-z0-9-]*$`, requiring **four hyphen-separated segments**: `{project}-{environment}-{resource-type}-{descriptor}`. The spec assumed `homeschoolio-{env}-rg` (only 3 segments), which would fail Conftest. Adding `-main` as the descriptor satisfies the policy while remaining meaningful.

**Alternatives considered**:
- `homeschoolio-{env}-rg` — only 3 segments, fails OPA naming policy
- `homeschoolio-{env}-rg-core` — acceptable; `main` chosen as simpler default
- Using a variable for the descriptor — adds unnecessary complexity for this use case

---

### 3. Required Tags

**Decision**: `Project`, `Environment`, `ManagedBy = "opentofu"`, `Owner = "justin-mckenzie"`

**Rationale**: The OPA tags policy (`policies/tags.rego`) enforces exactly these four tag keys (case-sensitive, PascalCase). The spec documented them as `project`, `environment`, `managed-by` (lowercase/kebab-case), which would fail Conftest. The actual required values from the existing `modules/example/main.tf` are the definitive reference.

**Alternatives considered**: The spec's assumption of `managed-by=terragrunt` is incorrect — the existing module uses `ManagedBy = "opentofu"`. Terragrunt is the orchestrator, not the state manager; OpenTofu performs the actual applies.

---

### 4. Terragrunt Root Location

**Decision**: `environments/{env}/resource-group/terragrunt.hcl` for dev, staging, production

**Rationale**: The existing pattern for `environments/{env}/infra/terragrunt.hcl` establishes subdirectory-per-logical-domain under each environment. A new `resource-group` subdirectory follows this pattern cleanly. The root `terragrunt.hcl` will auto-derive the environment from the path and configure the remote state container as `homeschoolio-{env}-infra-tfstate`.

**Alternatives considered**: A flat `environments/{env}/terragrunt.hcl` override was rejected — environment-level files currently act only as inheritance anchors, not deployment roots.

---

### 5. State Container

**Decision**: Reuse existing per-environment container `homeschoolio-{env}-infra-tfstate`

**Rationale**: The root `terragrunt.hcl` auto-generates the backend config using `${local.project}-${local.environment}-infra-tfstate` as the container name. The state key path is `{path_relative_to_include()}/terraform.tfstate`, which will resolve to `environments/{env}/resource-group/terraform.tfstate` — unique and collision-free within the shared container.

**Alternatives considered**: A dedicated container per root was evaluated but rejected — the constitution mandates one container per Terragrunt root only when state isolation is needed; sharing `infra-tfstate` is the existing pattern and the key path provides isolation.

---

### 6. Module Interface

**Decision**: Variables mirror `modules/example/`: `project`, `environment`, `location`, `owner`. No additional variables needed.

**Rationale**: The resource group is simple enough that no extra inputs are required. All four OPA-required tags map directly to these four variables. Additional tag customization is deferred as a MINOR version bump if needed.

**Alternatives considered**: An `additional_tags` map variable — deferred; YAGNI for a POC.

---

### 7. Module Version

**Decision**: Start at `1.0.0`

**Rationale**: This is a new module with a stable public interface (constitution Principle III). No prior version exists, so `1.0.0` is appropriate.

---

### 8. Spec Tag Discrepancy (Correction)

The spec's Assumptions section referenced `managed-by=terragrunt` (lowercase, kebab). The actual repo convention confirmed by `modules/example/main.tf` and `policies/tags.rego` is:

| Spec assumption | Actual required value |
|---|---|
| `managed-by` | `ManagedBy` |
| `terragrunt` | `opentofu` |
| `project` | `Project` |
| `environment` | `Environment` |

The module implementation will use the correct PascalCase tag keys and `opentofu` as the `ManagedBy` value.
