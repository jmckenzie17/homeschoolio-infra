# Tasks: Terraform Infrastructure Destroy Workflow

**Input**: Design documents from `/specs/004-terraform-destroy-workflow/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify prerequisites and establish the workflow file skeleton

- [x] T001 Read existing `.github/workflows/cd.yml` to understand the authentication pattern, secrets, and job structure to reuse in the destroy workflow
- [x] T002 Read existing `.github/workflows/ci.yml` to understand shared workflow references and action version pins in use
- [x] T003 Read root `terragrunt.hcl` and `environments/dev/terragrunt.hcl` to confirm environment path layout and backend config used by destroy steps

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create the base workflow file with trigger, permissions, concurrency, and environment inputs — required by all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create `.github/workflows/destroy.yml` with `workflow_dispatch` trigger only, `permissions: id-token: write, contents: read`, and `concurrency: group: cd-deployment, cancel-in-progress: false`
- [x] T005 Add `workflow_dispatch` inputs to `.github/workflows/destroy.yml`: `environment` (choice: dev/staging/production, required) and `confirm-destroy` (boolean, required, default false)
- [x] T006 Add per-environment jobs (`dev-destroy`, `staging-destroy`, `production-destroy`) each delegating to `jmckenzie17/homeschoolio-shared-actions/.github/workflows/destroy.yml@v1.5.0` with an `if: inputs.environment == '<env>'` gate, mirroring `cd.yml`'s apply pattern

**Checkpoint**: Base workflow file exists with correct trigger, concurrency, and abort gate — user story phases can now build on top

---

## Phase 3: User Story 1 - Manually Triggered Full Infrastructure Teardown (Priority: P1) 🎯 MVP

**Goal**: A confirmed workflow dispatch destroys all four Terragrunt roots for the selected environment in reverse dependency order, reporting per-root results

**Independent Test**: Trigger workflow against `dev` with `confirm_destroy: true`; verify all four roots are destroyed and each step shows pass/fail in the run log and step summary

### Implementation for User Story 1

- [x] T007 [US1] Verify shared `destroy.yml` interface: inputs `target-environment`, `confirm-destroy`; secrets `azure-client-id`, `azure-tenant-id`, `azure-subscription-id`, `github-token`, `pg_admin_password`
- [x] T008 [US1] Pass `confirm-destroy: ${{ inputs.confirm-destroy }}` to each per-environment shared workflow call so the confirmation gate is enforced inside the shared workflow
- [x] T009 [US1] Pass `pg_admin_password: ${{ secrets.TF_VAR_PG_ADMIN_PASSWORD }}` to each shared workflow call for PostgreSQL destroy support
- [x] T010 [US1] Pin shared workflow reference to `v1.5.0` in all three job `uses:` lines in `.github/workflows/destroy.yml`
- [x] T011 [US1] Confirm shared workflow handles `terragrunt run-all destroy` across all roots — verified via shared workflow source
- [x] T012 [US1] Confirm shared workflow writes job summary on success and failure — verified via shared workflow source (`if: always()` summary step)
- [x] T013 [US1] Final `.github/workflows/destroy.yml` written and structurally validated

**Checkpoint**: User Story 1 complete — operator can trigger a confirmed full teardown of any environment and see per-root results in the workflow run

---

## Phase 4: User Story 2 - Environment-Scoped Destroy (Priority: P2)

**Goal**: Only the selected environment's resources are destroyed; other environments are unaffected

**Independent Test**: Trigger destroy against `dev`; confirm `staging` and `production` Terragrunt state containers remain intact and no Azure resources outside `dev` are modified

### Implementation for User Story 2

- [x] T014 [US2] Verify each per-environment job in `.github/workflows/destroy.yml` uses a strict `if: inputs.environment == '<env>'` condition so only one environment's destroy job runs per trigger
- [x] T015 [US2] Verify each job has a descriptive `name:` (e.g., `Destroy dev`) so the run log and Actions UI clearly identifies the target environment

**Checkpoint**: User Story 2 complete — environment scoping is verified structural (path-based); no other-environment paths exist in destroy steps

---

## Phase 5: User Story 3 - Audit Trail of Destroy Operations (Priority: P3)

**Goal**: Every destroy run produces a visible audit record (actor, environment, timestamp, per-root outcome) accessible in GitHub Actions history

**Independent Test**: After a destroy run completes (success or failure), view the workflow run summary and confirm it shows actor, environment, timestamp, and per-root status

### Implementation for User Story 3

- [x] T016 [US3] Confirm shared workflow summary step includes environment, destroyed resource count, and success/failure status — verified via shared workflow source
- [x] T017 [US3] Confirm shared workflow summary runs with `if: always()` — verified via shared workflow source

**Checkpoint**: User Story 3 complete — full audit record written on every run, including partial-failure scenarios

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Workflow hardening and documentation

- [x] T018 [P] Add a workflow-level `name:` field to `.github/workflows/destroy.yml` (e.g., `name: Destroy Infrastructure`) so it appears clearly in the GitHub Actions sidebar
- [x] T019 [P] Add version pin comment to `.github/workflows/destroy.yml` documenting the shared workflow version in use (`v1.5.0`)
- [ ] T020 Run a manual dry-run validation: trigger the workflow with `confirm-destroy: false` and verify the shared workflow's confirmation gate causes all destroy jobs to fail without destroying any resources
- [x] T021 [P] Verify `.github/workflows/destroy.yml` passes `yamllint` or GitHub Actions syntax check (run `gh workflow view` or push branch and check Actions tab for parse errors)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — **blocks all user stories**
- **US1 (Phase 3)**: Depends on Phase 2 — core destroy capability
- **US2 (Phase 4)**: Depends on Phase 2; validates US1 structural correctness — can run after T007
- **US3 (Phase 5)**: Depends on T013 from Phase 3 (enhances the summary step)
- **Polish (Phase 6)**: Depends on all user story phases

### User Story Dependencies

- **User Story 1 (P1)**: After Phase 2 — no story dependencies
- **User Story 2 (P2)**: After Phase 2 — verifies US1 structure; tasks T014–T015 can start after T007
- **User Story 3 (P3)**: After T013 — enhances the summary step created in US1

### Parallel Opportunities

- T001, T002, T003 (Phase 1) — all parallel, different files
- T004, T005, T006 within Phase 2 are sequential (each builds on previous)
- T007, T008 within Phase 3 are parallel (auth setup + tool install)
- T009–T012 within Phase 3 are sequential (destroy order matters)
- T014, T015 (US2) are parallel
- T016, T017 (US3) are sequential (T017 modifies T016's step)
- T018, T019, T021 (Polish) are parallel

---

## Parallel Example: Phase 1

```
Launch together:
  T001 — read cd.yml
  T002 — read ci.yml
  T003 — read terragrunt.hcl files
```

## Parallel Example: Phase 3 (US1) start

```
Launch together:
  T007 — destroy job OIDC/auth setup steps
  T008 — Terragrunt install step
Then sequentially:
  T009 → T010 → T011 → T012 (destroy order)
  T013 (always-run summary step)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (read existing workflows)
2. Complete Phase 2: Foundational (workflow skeleton + confirmation gate)
3. Complete Phase 3: User Story 1 (four destroy steps + summary)
4. **STOP and VALIDATE**: Trigger against `dev` — confirm full teardown and summary
5. Merge or demo if ready

### Incremental Delivery

1. Phase 1 + 2 → Workflow file exists, aborts correctly without confirmation
2. Phase 3 (US1) → Full destroy capability, per-root reporting (**MVP**)
3. Phase 4 (US2) → Environment scoping verification (structural, minimal work)
4. Phase 5 (US3) → Enhanced audit trail
5. Phase 6 → Polish, comments, validation

---

## Notes

- [P] tasks = different files or no shared state, safe to run in parallel
- Destroy steps (T009–T012) are strictly sequential — order is `postgresql → key-vault → aks → resource-group`
- `TF_VAR_pg_admin_password` must be passed to the `postgresql` destroy step; other roots do not require it
- The `confirm_destroy` boolean renders as a checkbox in the GitHub Actions UI — no string to type
- All action version pins should match what is already in `cd.yml` for consistency
