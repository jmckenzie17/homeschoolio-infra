# Tasks: Azure Resource Group for Homeschoolio

**Input**: Design documents from `/specs/002-azure-resource-group/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the module scaffold and shared file structure that all environment roots depend on.

- [x] T001 Create module directory `modules/azure-resource-group/` (empty, ready for HCL files)
- [x] T002 [P] Create `modules/azure-resource-group/version.tf` with `module_version = "1.0.0"`
- [x] T003 [P] Create `modules/azure-resource-group/variables.tf` with `project`, `environment`, `location`, `owner` variables (mirror `modules/example/variables.tf` exactly, changing only defaults if needed)
- [x] T004 [P] Create `modules/azure-resource-group/outputs.tf` with `resource_group_name` and `resource_group_id` outputs
- [x] T005 Create `modules/azure-resource-group/main.tf` with provider block (`azurerm`, `use_oidc = true`, `skip_provider_registration = true`), `required_version >= 1.6`, `azurerm ~> 3.0`, and `azurerm_resource_group.this` named `"${var.project}-${var.environment}-rg-main"` with required tags `Project`, `Environment`, `ManagedBy = "opentofu"`, `Owner`

**Checkpoint**: Module scaffold complete — `modules/azure-resource-group/` contains all four HCL files.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Wire the module into the Terragrunt environment roots. All three roots must exist before any story can be applied.

**⚠️ CRITICAL**: No environment apply can succeed until this phase is complete.

- [x] T006 Create directory `environments/dev/resource-group/` and `environments/dev/resource-group/terragrunt.hcl` with `include "root"` + `find_in_parent_folders()` and `terraform.source = "${get_repo_root()}//modules/azure-resource-group"` and `inputs = { environment = "dev" }`
- [x] T007 [P] Create directory `environments/staging/resource-group/` and `environments/staging/resource-group/terragrunt.hcl` (same pattern as T006, `environment = "staging"`)
- [x] T008 [P] Create directory `environments/production/resource-group/` and `environments/production/resource-group/terragrunt.hcl` (same pattern as T006, `environment = "production"`)
- [x] T009 Add `1.0.0` entry to `CHANGELOG.md` for the new `azure-resource-group` module (constitution Principle III requirement)

**Checkpoint**: Foundation ready — module + all three Terragrunt roots exist. User story work can begin.

---

## Phase 3: User Story 1 — Provision Resource Group via Terraform (Priority: P1) 🎯 MVP

**Goal**: An engineer can run `terragrunt plan` and `terragrunt apply` in `environments/dev/resource-group/` and the resource group `homeschoolio-dev-rg-main` is created in Azure with correct name, location, and tags. Re-applying produces a no-op plan.

**Independent Test**: `cd environments/dev/resource-group && terragrunt plan` — expect 1 resource to add. After apply: `az group show --name homeschoolio-dev-rg-main` returns the group with all four required tags. Second `terragrunt plan` shows no changes.

### Implementation for User Story 1

- [ ] T010 [US1] Validate `modules/azure-resource-group/main.tf` locally: run `terragrunt validate` from `environments/dev/resource-group/` and resolve any HCL errors
- [ ] T011 [US1] Run `terragrunt plan` from `environments/dev/resource-group/` and verify the plan shows exactly 1 resource to add (`azurerm_resource_group.this`) with name `homeschoolio-dev-rg-main`, location `eastus`, and all four tags present
- [ ] T012 [US1] Run `terragrunt apply` from `environments/dev/resource-group/` and confirm the resource group appears in Azure
- [ ] T013 [US1] Verify idempotency: run `terragrunt plan` again from `environments/dev/resource-group/` and confirm output shows `No changes`

**Checkpoint**: User Story 1 complete — `homeschoolio-dev-rg-main` exists in Azure, plan is clean, idempotency confirmed.

---

## Phase 4: User Story 2 — Consistent Tagging Across Environments (Priority: P2)

**Goal**: Staging and production resource groups can be provisioned with environment-specific names and correct tags using the same module code, with only Terragrunt input differences.

**Independent Test**: `cd environments/staging/resource-group && terragrunt plan` shows `homeschoolio-staging-rg-main` with `Environment = "staging"` tag. Can be applied and verified without any module code changes.

### Implementation for User Story 2

- [ ] T014 [P] [US2] Run `terragrunt validate` from `environments/staging/resource-group/` and resolve any issues
- [ ] T015 [P] [US2] Run `terragrunt validate` from `environments/production/resource-group/` and resolve any issues
- [ ] T016 [US2] Run `terragrunt plan` from `environments/staging/resource-group/` and verify plan shows `homeschoolio-staging-rg-main` with `Environment = "staging"` tag — confirm no module code changes were required
- [ ] T017 [US2] Run `terragrunt plan` from `environments/production/resource-group/` and verify plan shows `homeschoolio-production-rg-main` with `Environment = "production"` tag

**Checkpoint**: User Story 2 complete — all three environment plans are clean and show correct environment-scoped names and tags.

---

## Phase 5: User Story 3 — Resource Group Destruction (Priority: P3)

**Goal**: An engineer can run `terragrunt destroy` in the dev environment and the resource group is cleanly removed from Azure.

**Independent Test**: `cd environments/dev/resource-group && terragrunt destroy` completes successfully. `az group show --name homeschoolio-dev-rg-main` returns a 404/not-found error afterward.

### Implementation for User Story 3

- [ ] T018 [US3] Re-apply dev environment if needed (`terragrunt apply` from `environments/dev/resource-group/`) to have a resource group to destroy
- [ ] T019 [US3] Run `terragrunt destroy` from `environments/dev/resource-group/` and confirm the resource group is removed from Azure
- [ ] T020 [US3] Re-apply dev environment after destroy test (`terragrunt apply` from `environments/dev/resource-group/`) to restore it for ongoing development

**Checkpoint**: User Story 3 complete — destroy/re-create cycle confirmed in dev.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Static analysis validation, CI verification, and documentation hygiene.

- [ ] T021 [P] Run `tfsec modules/azure-resource-group/` and resolve any HIGH/CRITICAL findings (constitution Principle VI gate)
- [ ] T022 [P] Run `checkov -d modules/azure-resource-group/` and resolve any HIGH/CRITICAL findings
- [ ] T023 Run Conftest OPA policy checks: generate a plan JSON from `environments/dev/resource-group/` and run `conftest test` against `policies/` — verify zero naming and tags violations
- [ ] T024 Verify CI pipeline runs successfully on the feature branch PR (validate, plan, policy scan gates all pass)
- [x] T025 [P] Update `specs/002-azure-resource-group/spec.md` to correct tag casing (`ManagedBy`, `Project`, `Environment`, `Owner`) and resource name pattern (`homeschoolio-{env}-rg-main`) across FR-001, FR-003, Key Entities, and Assumptions — resolved by `/speckit.specify 002` on 2026-03-27

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately. T002, T003, T004 are parallel; T005 depends on T003.
- **Foundational (Phase 2)**: Depends on Phase 1 completion. T007 and T008 are parallel with T006.
- **User Stories (Phases 3–5)**: All depend on Foundational phase completion.
  - US1 (Phase 3): Must complete before US3 (destroy/re-apply cycle).
  - US2 (Phase 4): Independent of US1; can run in parallel with Phase 3 if environment access allows.
  - US3 (Phase 5): Requires US1 (dev resource group must exist to destroy).
- **Polish (Phase 6)**: Depends on all desired user stories complete. T021 and T022 can run in parallel.

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2. No story dependencies.
- **US2 (P2)**: Can start after Phase 2. Independent of US1 (different environment roots).
- **US3 (P3)**: Depends on US1 (needs an existing dev resource group to destroy).

### Within Each User Story

- Validate → Plan → Apply → Verify (sequential)
- US2: staging validate and production validate can run in parallel (T014 ∥ T015), then plans are independent

---

## Parallel Example: User Story 2

```bash
# These two tasks touch different files and can run concurrently:
Task T014: terragrunt validate in environments/staging/resource-group/
Task T015: terragrunt validate in environments/production/resource-group/

# Then independently:
Task T016: terragrunt plan for staging
Task T017: terragrunt plan for production
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup — create `modules/azure-resource-group/` (T001–T005)
2. Complete Phase 2: Foundational — create dev Terragrunt root minimum (T006, T009)
3. Complete Phase 3: User Story 1 — validate, plan, apply, verify idempotency (T010–T013)
4. **STOP and VALIDATE**: Dev resource group exists, plan is clean
5. Staging/production roots (T007, T008) and US2/US3 can follow

### Incremental Delivery

1. Phase 1 + Phase 2 → Module + all roots ready
2. Phase 3 (US1) → Dev resource group provisioned ✅ MVP
3. Phase 4 (US2) → Staging + production plans validated ✅
4. Phase 5 (US3) → Destroy cycle confirmed ✅
5. Phase 6 → All CI gates pass, PR ready to merge ✅

---

## Notes

- [P] tasks operate on different files with no shared state — safe to parallelize
- [Story] labels enable tracing each task back to its acceptance scenarios in spec.md
- All `terragrunt` commands must be run from within the specific root directory, not the repo root
- US3 destroy test should only be run in dev — never staging/production without explicit runbook
- Commit after each phase checkpoint at minimum; prefer per-task commits for clean git history
