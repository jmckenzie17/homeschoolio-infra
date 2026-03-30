# Feature Specification: Terraform Infrastructure Destroy Workflow

**Feature Branch**: `004-terraform-destroy-workflow`
**Created**: 2026-03-30
**Status**: Draft
**Input**: User description: "create a github workflow to destroy all terraform infrastructure"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Manually Triggered Full Infrastructure Teardown (Priority: P1)

An operator needs to tear down all Terraform-managed infrastructure across all Terragrunt roots for a given environment. They trigger a GitHub Actions workflow manually, select the target environment, confirm the destructive intent, and the workflow destroys all resources in dependency order.

**Why this priority**: This is the core capability requested. Without it, the feature has no value.

**Independent Test**: Can be fully tested by triggering the workflow against a non-production environment and verifying all managed resources are removed.

**Acceptance Scenarios**:

1. **Given** the workflow is triggered manually with environment `dev`, **When** the operator provides the correct confirmation string, **Then** all Terraform-managed resources in `dev` are destroyed and the run reports success or failure per Terragrunt root.
2. **Given** the workflow is triggered without the correct confirmation input, **When** the workflow evaluates the input, **Then** it exits without destroying anything and reports that confirmation was not provided.
3. **Given** a destroy run is in progress, **When** a Terragrunt root fails to destroy, **Then** the workflow reports the failure clearly and halts further destruction to prevent orphaned dependencies.

---

### User Story 2 - Environment-Scoped Destroy (Priority: P2)

An operator wants to destroy infrastructure for a specific environment (e.g., `dev`) without affecting other environments (e.g., `staging`, `production`).

**Why this priority**: Prevents accidental cross-environment destruction; critical for safe operations.

**Independent Test**: Can be tested by destroying `dev` and confirming `staging` and `production` resources remain intact.

**Acceptance Scenarios**:

1. **Given** the operator selects `dev` as the target environment, **When** the workflow runs, **Then** only resources associated with the `dev` environment are destroyed.
2. **Given** the operator selects `production` as the target environment, **When** the operator provides the correct confirmation string, **Then** production resources are destroyed using the same confirmation behavior as all other environments.

---

### User Story 3 - Audit Trail of Destroy Operations (Priority: P3)

A team lead or auditor can review who triggered the destroy workflow, when, against which environment, and what the outcome was.

**Why this priority**: Operational safety and accountability; lower priority as the primary value is the destruction capability itself.

**Independent Test**: After a destroy run completes, the GitHub Actions run log and summary show actor, environment, timestamp, and per-root results.

**Acceptance Scenarios**:

1. **Given** a destroy workflow run completes, **When** an auditor views the workflow run summary, **Then** they can see the triggering actor, selected environment, timestamp, and success/failure status for each Terragrunt root.

---

### Edge Cases

- What happens when one Terragrunt root has resources with deletion protection enabled?
- How does the workflow handle partial failures — are remaining roots attempted or is the run halted?
- What happens if the state backend is unreachable at destroy time?
- What if a destroy is triggered concurrently with a plan/apply workflow on the same environment?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The workflow MUST be manually triggered and MUST NOT run automatically on push or pull request events.
- **FR-002**: The workflow MUST require the operator to select a target environment (`dev`, `staging`, or `production`) as a required input parameter.
- **FR-003**: The workflow MUST require an explicit confirmation input before executing any destroy operations; the run MUST abort if confirmation is not provided or does not match the expected value.
- **FR-004**: The workflow MUST discover and destroy all Terragrunt roots associated with the selected environment.
- **FR-005**: The workflow MUST destroy Terragrunt roots in reverse dependency order to avoid resource dependency failures.
- **FR-006**: The workflow MUST report per-root success or failure in the job summary and workflow logs.
- **FR-007**: The workflow MUST use the same authentication and state backend configuration as existing CI/CD workflows in the repository. Destroy execution for each environment MUST delegate to the shared `destroy.yml` reusable workflow in `jmckenzie17/homeschoolio-shared-actions`, mirroring the pattern used for applies in `cd.yml`.
- **FR-008**: The workflow MUST surface any errors from individual Terragrunt root destroy operations and fail the overall workflow if any root fails.

### Key Entities

- **Environment**: A named deployment target (`dev`, `staging`, `production`) scoping which infrastructure roots are destroyed.
- **Terragrunt Root**: An independent deployable unit of Terraform configuration managed by Terragrunt; multiple roots exist per environment.
- **Destroy Run**: A single execution of the workflow for a given environment, producing per-root outcomes and an overall result.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can initiate a full environment teardown in under 5 minutes of human interaction time (excluding resource deletion duration).
- **SC-002**: 100% of Terraform-managed resources in the target environment are removed on a successful destroy run, with no orphaned resources.
- **SC-003**: A destroy run without a valid confirmation input is rejected in under 30 seconds without destroying any resources.
- **SC-004**: Every destroy run produces a complete audit record (actor, environment, timestamp, per-root outcome) visible in the workflow run history.
- **SC-005**: The workflow does not affect infrastructure in any environment other than the one explicitly selected.

## Assumptions

- All environments (`dev`, `staging`, `production`) follow the same Terragrunt root structure used in existing CI/CD workflows.
- The workflow will reuse the same Azure credentials already configured in the repository for existing plan/apply workflows.
- Remote state is stored in Azure Blob Storage as per the existing backend configuration; no additional state migration is required for destroy.
- Destroy operations run sequentially across Terragrunt roots (not in parallel) to respect dependency order; parallelism is out of scope for v1.
- The workflow targets all Terragrunt roots for the selected environment; selective per-root destruction is out of scope.
- GitHub Actions UI is the only trigger surface; no external triggering mechanism is required.
- The destroy operation for each environment MUST be implemented by calling a shared reusable workflow (`destroy.yml`) from the `jmckenzie17/homeschoolio-shared-actions` repository, consistent with how apply operations are implemented in `cd.yml`. Inline destroy steps are not acceptable.

## Clarifications

### Session 2026-03-30

- Q: How should the destroy operation be invoked per environment? → A: Use the shared `destroy.yml` reusable workflow from `jmckenzie17/homeschoolio-shared-actions`, consistent with the apply pattern in `cd.yml`.
