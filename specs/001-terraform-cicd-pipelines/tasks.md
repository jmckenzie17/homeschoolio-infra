---
description: "Task list for OpenTofu/Terragrunt CI/CD Pipelines with Semantic Versioning"
---

# Tasks: OpenTofu/Terragrunt CI/CD Pipelines with Semantic Versioning

**Input**: Design documents from `/specs/001-terraform-cicd-pipelines/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Not explicitly requested in spec — test tasks omitted. Infrastructure
tests (tfsec, Checkov, Conftest) are themselves the deliverable, not test tasks
for the pipeline code.

**Shared actions repo**: `jmckenzie17/homeschoolio-shared-actions`
**Semver release**: driven by conventional commits via `semver-release.yml` embedded in `cd.yml`

**Scope note**: CD pipeline targets `dev` only. Staging/production promotion deferred
to a future feature (spec clarification 2026-03-30).

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Exact file paths included in all descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository scaffolding and shared configuration that all stories depend on.

- [x] T001 Create `.github/workflows/` directory structure at repo root
- [x] T002 Create `policies/` directory for OPA/Conftest policies at repo root
- [x] T003 [P] Create `.opentofu-version` at repo root pinned to `1.6.2`
- [x] T004 [P] Create `.terragrunt-version` at repo root pinned to `0.56.3`
- [x] T005 [P] Create `modules/example/version.tf` with `locals { module_version = "1.0.0" }` as canonical module version template
- [x] T006 Create `CHANGELOG.md` at repo root with initial unreleased entry per constitution Principle III
- [x] T007 Create `.gitignore` at repo root with OpenTofu, Terragrunt, secrets, and editor patterns

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Policies, Terragrunt roots, module, and shared workflow library that ALL user stories require.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T008 Create `policies/tags.rego` — OPA/Conftest policy enforcing required Azure tags (`Project`, `Environment`, `ManagedBy`, `Owner`) with human-readable deny messages including resource address and missing tag name
- [x] T009 [P] Create `policies/naming.rego` — OPA/Conftest policy enforcing naming convention `{project}-{environment}-{resource-type}-{descriptor}` against plan JSON for enforced Azure resource types
- [x] T010 Verify `jmckenzie17/homeschoolio-shared-actions` repository exists and contains `.github/workflows/` directory with `validate.yml`, `plan.yml`, `test.yml`, `apply.yml`, and `semver-release.yml`
- [x] T037 [P] Create root `terragrunt.hcl` at repo root — shared backend generation (AzureRM backend + remote state pointing to `homeschooliostfstate`; container name `homeschoolio-{env}-infra-tfstate`) and common inputs (`project`, `environment`, `location`)
- [x] T038 [P] Create `environments/dev/terragrunt.hcl` — environment-level locals file for `dev`
- [x] T039 [P] Create `environments/dev/infra/terragrunt.hcl` — concrete Terragrunt root calling `modules/example`; include `root` via `find_in_parent_folders()`
- [x] T040 [P] Flesh out `modules/example/` — add `variables.tf` (project, environment, location, owner), `main.tf` (azurerm_resource_group with all required tags), `outputs.tf` (resource_group_name, resource_group_id)

**Checkpoint**: Policies written; dev environment root in place; shared workflows confirmed live. User story work can begin.

---

## Phase 3: User Story 1 — PR Triggers CI Pipeline Automatically (Priority: P1) 🎯 MVP

**Goal**: Every PR targeting `main` automatically runs validate → plan → test and posts
results to the PR checks panel within 5 minutes. Merge is blocked until all pass.
Destructive operations must be explicitly acknowledged in the PR description.

**Independent Test**: Open a PR with a trivial `.hcl` change; verify CI triggers within
2 minutes, all three check stages appear in the GitHub PR checks panel, and the merge
button is blocked until they pass.

### Implementation for User Story 1

- [x] T016 [US1] Create `.github/workflows/ci.yml` — caller workflow triggered on `pull_request` (opened, synchronize, reopened) targeting `main`; jobs: `validate` → `plan` (with `environments: "dev"`) → `test`; `destructive-op-gate` job checks PR body for `- [x] I acknowledge destructive operations` when `has-destructive-ops == 'true'`; all jobs call `jmckenzie17/homeschoolio-shared-actions` workflows at pinned `v1.3.6`
- [x] T017 [US1] Update `.github/workflows/ci.yml` — change `plan` job `with.environments` from `"dev,staging,production"` to `"dev"` (FR-007b; aligns with dev-only scope clarification 2026-03-30)
- [x] T018 [US1] Configure GitHub branch protection on `main` via repository Settings: require status checks `Validate`, `Plan`, `Test`, `Destructive Operation Gate` to pass; require at least 1 PR review approval; document steps in `specs/001-terraform-cicd-pipelines/quickstart.md`

**Checkpoint**: US1 complete — PRs get automatic CI results and merge is gated on `dev` plan.

---

## Phase 4: User Story 2 — CI Detects and Reports Test Failures (Priority: P1)

**Goal**: The `test` stage fails with specific, actionable error messages naming the
resource and violated rule; passes when all policies are satisfied.

**Independent Test**: Push a branch adding an Azure resource missing the `Owner` tag;
verify the `test` check fails and the output names the specific resource address and
missing tag. Fix the tag and verify the check passes.

### Implementation for User Story 2

- [x] T019 [P] [US2] Verify `policies/tags.rego` produces deny messages in format `"Resource {address} ({type}) is missing required tag: {tag}"` — the current implementation already does this; no changes needed if correct
- [x] T020 [US2] Create `policies/README.md` documenting each policy file (`tags.rego`, `naming.rego`): what each rule enforces, example violations, and how to fix them — referenced from CI failure output annotations
- [x] T021 [P] [US2] Confirm Conftest invocation in shared `test.yml` uses `conftest test tfplan.json -p policies/ --all-namespaces --output github` (or equivalent); verify `policies/` directory is included in the test run

**Checkpoint**: US1 + US2 complete — CI both triggers automatically and surfaces actionable test failures.

---

## Phase 5: User Story 3 — Merge to Main Deploys to Dev (Priority: P2)

**Goal**: When a qualifying conventional commit is merged to `main`, the CD pipeline
runs `semantic-release` (in the `release` job of `cd.yml`), creates a semver tag/release,
and automatically applies to `dev` (in the `dev-apply` job gated on
`release-created == 'true'`). No staging or production promotion in scope.

**Independent Test**: Merge a PR with a `feat:` commit; verify the CD workflow triggers
on push to `main`, the `release` job creates a GitHub release, and the `dev-apply` job
applies to `dev` within 5 minutes. Verify no staging or production jobs appear.

### Implementation for User Story 3

- [x] T022 [US3] Remove `workflow_dispatch` trigger block from `.github/workflows/cd.yml` — the `inputs:` section with `target-environment` choice (staging/production) is out of scope; only `on: push: branches: [main]` trigger is needed (FR-008, FR-009 out of scope)
- [x] T023 [US3] Remove `staging-apply` job from `.github/workflows/cd.yml` — staging promotion deferred to future feature (spec clarification 2026-03-30)
- [x] T024 [US3] Remove `production-apply` job from `.github/workflows/cd.yml` — production promotion deferred to future feature (spec clarification 2026-03-30)
- [x] T025 [P] [US3] Configure `dev` GitHub environment in repository Settings → Environments: create `dev` with no protection rules; add Azure OIDC secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) scoped to `dev`; document in `specs/001-terraform-cicd-pipelines/quickstart.md`

**Checkpoint**: US3 complete — push to main creates a release and auto-applies to dev only.

---

## Phase 6: User Story 4 — Conventional Commits Trigger Semantic Version Release (Priority: P2)

**Goal**: Merging a PR with qualifying conventional commits (`feat:`, `fix:`,
`BREAKING CHANGE`) to `main` automatically creates a semver Git tag (e.g., `v1.2.3`)
and updates the floating major pointer (`v1`) within 2 minutes, using the `release` job
in `cd.yml` which calls `jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml`.

**Independent Test**: Merge a PR with commit message `feat: add vpc module`; verify Git
tag `v{NEXT_MINOR}` and updated `v{MAJOR}` pointer appear within 2 minutes. Merge a
`chore:` PR and verify no new tag is created and `dev-apply` does not run.

### Implementation for User Story 4

- [x] T026 [US4] Verify `CONTRIBUTING.md` at repo root documents conventional commit format: `feat:` (minor bump), `fix:` (patch bump), `chore:`/`docs:` (no release), `BREAKING CHANGE` footer (major bump); add if missing
- [x] T027 [US4] Verify `cd.yml` `release` job calls `jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml` at a pinned semver tag (not `@main`); inputs: `release-branch: main`, `tag-prefix: "v"`, `secrets: inherit`; outputs consumed: `release-created`, `tag-name`, `major-tag` (FR-011, constitution Principle III)
- [x] T028 [US4] Update `specs/001-terraform-cicd-pipelines/quickstart.md` — add semver validation steps: merge a `feat:` commit, verify tag created and `dev-apply` runs; merge a `chore:` commit, verify no tag and `dev-apply` skipped; reference a tag from a downstream `terragrunt.hcl` source

**Checkpoint**: US4 complete — semantic version tags created automatically by conventional commits via `cd.yml`.

---

## Phase 7: User Story 5 — Shared Workflows Reused from jmckenzie17/homeschoolio-shared-actions (Priority: P3)

**Goal**: All CI/CD pipeline logic lives in `jmckenzie17/homeschoolio-shared-actions`
at a pinned semver tag. No workflow logic is duplicated in this repo's
`.github/workflows/` files. Upgrading requires only a single-line version bump PR.

**Independent Test**: Verify all `uses:` lines in `ci.yml` and `cd.yml` reference
`jmckenzie17/homeschoolio-shared-actions` at an explicit semver tag; no inline logic
exists in either file; upgrading the tag in the comment at the top and all `uses:` lines
is the complete upgrade procedure.

### Implementation for User Story 5

- [x] T029 [US5] Audit `.github/workflows/ci.yml` and `cd.yml`: confirm all substantive logic is in shared workflows; only `uses:`, `with:`, `secrets:`, `needs:`, `if:`, `concurrency:`, and `on:` declarations are permitted locally; fix any inline logic found
- [x] T030 [US5] Verify all `uses:` lines in `ci.yml` and `cd.yml` pin to `v1.3.6` (or the same explicit semver tag); the version comment at the top of each file tracks the current pinned version; floating `@main` is forbidden per FR-011 and constitution Principle III
- [x] T031 [US5] Update `specs/001-terraform-cicd-pipelines/quickstart.md` — document shared workflow upgrade process: check `jmckenzie17/homeschoolio-shared-actions` releases, open PR bumping the pinned version in every `uses:` line in `ci.yml` and `cd.yml`, update the version comment at top of each file, verify CI passes, merge

**Checkpoint**: All 5 user stories complete — full CI/CD pipeline operational (dev-only scope).

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, documentation, and compliance items that span all stories.

- [x] T032 [P] Update `CHANGELOG.md` — document `ci.yml`/`cd.yml` scope changes, `policies/README.md` addition, and link to `jmckenzie17/homeschoolio-shared-actions` tag
- [x] T033 [P] Verify all Azure infrastructure referenced by the pipeline (state storage accounts, Key Vault) carries required tags (`Project`, `Environment`, `ManagedBy = "opentofu"`, `Owner`) — add or extend `policies/tags.rego` if any resource types are not covered
- [x] T034 ~~Add Infracost workflow~~ — superseded by constitution v1.1.0; cost awareness achieved via lowest-cost tier selection at authoring time; Infracost not required for POC
- [x] T035 [P] Update `specs/001-terraform-cicd-pipelines/checklists/requirements.md` — mark all items complete after end-to-end quickstart validation
- [x] T037 [P] Create root `terragrunt.hcl` at repo root — shared backend generation
- [x] T038 [P] Create environment-level `terragrunt.hcl` files for dev, staging, production
- [x] T039 [P] Create `environments/{dev,staging,production}/infra/terragrunt.hcl` concrete roots
- [x] T040 [P] Flesh out `modules/example/` with variables, main, outputs
- [x] T041 Remove `homeschoolio-shared-workflows/` local directory — all workflows in shared-actions
- [ ] T036 Run full `specs/001-terraform-cicd-pipelines/quickstart.md` validation checklist end-to-end; confirm all acceptance criteria pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately; T003–T007 all parallel
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories; T037–T040 parallel after T010
- **US1 (Phase 3)**: Depends on Phase 2 complete; T017 is a 1-line change to existing `ci.yml`
- **US2 (Phase 4)**: Depends on Phase 2; T020 runs parallel to US1 (different files)
- **US3 (Phase 5)**: T022–T024 are removals from existing `cd.yml` (no dependencies); T025 is GitHub UI config
- **US4 (Phase 6)**: T027 already verified; T028 is quickstart update (after US3 complete)
- **US5 (Phase 7)**: Depends on US1–US4 complete (audit requires all workflows in final state)
- **Polish (Phase 8)**: Depends on US1–US5 and all gap remediations complete

### User Story Dependencies

- **US1 (P1)**: After Foundational — T017 (1-line change) + T018 (branch protection)
- **US2 (P1)**: After Foundational — T020 (README) parallel with US1
- **US3 (P2)**: T022–T024 (removals from cd.yml) independent; T025 (GitHub UI)
- **US4 (P2)**: T028 (quickstart) after US3 validated
- **US5 (P3)**: After US1–US4 all complete

### Parallel Opportunities

- T003–T007 (Setup): all parallel
- T037–T040 (Foundational roots/module): all parallel after T010
- T017 (US1 ci.yml fix) + T020 (US2 README) + T022–T024 (US3 cd.yml removals): parallel (different files)
- T032 + T033 + T035 (Polish): parallel

---

## Parallel Example: Gap Remediation (US1 + US3)

```bash
# These touch different files — run in parallel:
Task: "Update ci.yml plan job environments to 'dev'"   # T017
Task: "Remove workflow_dispatch block from cd.yml"      # T022
Task: "Remove staging-apply job from cd.yml"            # T023
Task: "Remove production-apply job from cd.yml"         # T024
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only)

1. Complete Phase 1: Setup — ✅ Done
2. Complete Phase 2: Foundational — ✅ Done (policies, roots, module)
3. Complete Phase 3: US1 — T017 (1-line ci.yml fix), T018 (branch protection)
4. Complete Phase 4: US2 — T020 (policies README)
5. **STOP and VALIDATE**: Open a test PR, introduce a tag violation, confirm CI fails with actionable output; fix, confirm pass; verify merge blocked until pass
6. MVP deployed: every PR has automated safety gates scoped to `dev`

### Incremental Delivery

1. Setup + Foundational → ✅ Complete
2. US1 (T017, T018) + US2 (T020) → CI pipeline on all PRs (MVP)
3. US3 (T022–T025) → CD pipeline applies to dev automatically on merge
4. US4 (T028) → Semver release quickstart documented
5. US5 (T031) → Shared workflow reuse audited and documented
6. Polish (T032, T035, T036) → CHANGELOG, checklist, end-to-end validation

---

## Notes

- `[P]` tasks operate on different files with no unresolved dependencies — safe to run concurrently
- `[Story]` label maps each task to its user story for traceability to spec.md
- Shared-actions repo: `jmckenzie17/homeschoolio-shared-actions` (pinned at `v1.3.6`)
- `semver-release.yml` is called from the `release` job inside `cd.yml` — no separate `release.yml` exists
- Caller workflows MUST remain thin (no inline logic per US5 / constitution Principle III)
- Azure credentials: use OIDC workload identity federation (not long-lived service principal secrets)
- Staging/production environment roots (`environments/staging/`, `environments/production/`) exist in the repo but are NOT targeted by any CD job in this feature
- T022–T024 are pure removals from `cd.yml` — the resulting file should contain only `release` and `dev-apply` jobs
