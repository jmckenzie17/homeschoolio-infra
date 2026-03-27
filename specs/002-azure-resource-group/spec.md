# Feature Specification: Azure Resource Group for Homeschoolio

**Feature Branch**: `002-azure-resource-group`
**Created**: 2026-03-27
**Status**: Ready
**Input**: User description: "create a resource group that will hold homeschoolio resources"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision Resource Group via Terraform (Priority: P1)

An infrastructure engineer applies the Terraform/Terragrunt configuration to create an Azure resource group that serves as the logical container for all homeschoolio application resources. The resource group is created idempotently — running apply multiple times produces no unintended changes.

**Why this priority**: The resource group is a foundational prerequisite. No other Azure resources can be deployed until this container exists.

**Independent Test**: Can be fully tested by running `terragrunt apply` in the resource group module and verifying the group appears in Azure with the correct name, location, and tags.

**Acceptance Scenarios**:

1. **Given** no resource group exists, **When** an engineer runs the Terragrunt apply, **Then** an Azure resource group is created with the expected name, location, and tags.
2. **Given** the resource group already exists, **When** an engineer runs the Terragrunt apply again, **Then** no changes are made (idempotent behavior confirmed by zero-diff plan).
3. **Given** the resource group exists, **When** an engineer runs a Terragrunt plan, **Then** the plan output shows no changes pending.

---

### User Story 2 - Consistent Tagging Across Environments (Priority: P2)

An infrastructure engineer can deploy the resource group to dev, staging, and production environments with environment-specific naming and tags, using the existing per-environment Terragrunt structure.

**Why this priority**: Environment isolation is a core principle of this project. The resource group must be distinguishable per environment to support separate lifecycle management.

**Independent Test**: Can be tested by applying to the dev environment root and verifying the resource group name and tags reflect the dev environment context.

**Acceptance Scenarios**:

1. **Given** the dev environment Terragrunt root is targeted, **When** applied, **Then** a resource group named for the dev environment is created with a tag identifying it as `dev`.
2. **Given** separate environments (dev, staging, production), **When** each is applied independently, **Then** each has a distinct resource group with correct environment-specific tags.

---

### User Story 3 - Resource Group Destruction (Priority: P3)

An infrastructure engineer can cleanly destroy the resource group when decommissioning an environment.

**Why this priority**: Cleanup capability is required for cost management and environment lifecycle control, but is lower priority than initial provisioning.

**Independent Test**: Can be tested in the dev environment by running `terragrunt destroy` and confirming the resource group no longer exists in Azure.

**Acceptance Scenarios**:

1. **Given** an empty resource group exists, **When** an engineer runs `terragrunt destroy`, **Then** the resource group is removed from Azure.
2. **Given** a resource group with child resources, **When** destroy is attempted, **Then** the operation succeeds and all child resources within the group are deleted by the cloud provider as part of the group removal.

---

### Edge Cases

- What happens when the resource group name conflicts with an existing group owned outside this Terraform state?
- How does the system behave when Azure permissions are insufficient to create a resource group?
- What occurs if the specified Azure region name is invalid or unavailable?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST create an Azure resource group with a configurable name scoped to the environment following the 4-segment naming convention (e.g., `homeschoolio-dev-rg-main`, `homeschoolio-production-rg-main`).
- **FR-002**: The resource group MUST be created in a configurable Azure region, defaulting to `eastus` consistent with existing infrastructure.
- **FR-003**: The resource group MUST be tagged with at minimum: `Project`, `Environment`, `ManagedBy`, and `Owner` tags (PascalCase, enforced by the OPA tags policy).
- **FR-004**: The Terragrunt module MUST integrate with the existing remote state backend (Azure Blob Storage) used by other roots in this repository.
- **FR-005**: The resource group configuration MUST be deployable independently per environment using the existing Terragrunt environment directory structure.
- **FR-006**: The module MUST pass existing static analysis checks (tfsec, Checkov, Conftest) without suppression overrides.
- **FR-007**: The resource group name and region MUST be configurable as Terragrunt inputs, not hard-coded.

### Key Entities

- **Resource Group**: The Azure logical container for homeschoolio resources. Key attributes: name (4-segment, environment-scoped, e.g., `homeschoolio-dev-rg-main`), location (Azure region), tags (`Project`, `Environment`, `ManagedBy`, `Owner`).
- **Terragrunt Root**: The per-environment configuration directory that wires inputs into the OpenTofu module and configures the remote state backend.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An engineer can provision the resource group in any target environment with a single apply command and zero manual portal steps.
- **SC-002**: A plan against an already-provisioned resource group shows zero changes (idempotency verified).
- **SC-003**: The resource group appears in Azure within 2 minutes of a successful apply.
- **SC-004**: All static analysis checks pass without warnings or suppressions in the CI pipeline.
- **SC-005**: The same module code supports dev, staging, and production environments with only Terragrunt input differences.

## Assumptions

- The existing Terragrunt environment directory structure will be extended with a new `resource-group` root following established conventions.
- The Azure region `eastus` is the default, consistent with the existing `homeschooliostfstate` storage account location.
- Resource group naming convention will follow the pattern `homeschoolio-{env}-rg-main` (4 segments required by OPA naming policy; confirmed by `policies/naming.rego`).
- The module will reuse the existing Azure remote state backend and will not require a new storage account or container.
- Authentication to Azure in CI is already handled by existing workflow credentials; no new service principal setup is in scope.
- Required tags (PascalCase, enforced by `policies/tags.rego`): `Project=homeschoolio`, `Environment={env}`, `ManagedBy=opentofu`, `Owner=justin-mckenzie`; additional tags can be supplied via inputs.
