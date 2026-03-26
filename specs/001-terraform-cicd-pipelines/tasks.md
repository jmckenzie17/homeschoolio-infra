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
**Semver release**: driven by conventional commits via `semver-release.yml` (not version.tf bumps)

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

**Purpose**: Policies, shared workflow library, and project structure that ALL user stories require.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T008 Create `policies/tags.rego` — OPA/Conftest policy enforcing required Azure tags (`Project`, `Environment`, `ManagedBy`, `Owner`) with human-readable deny messages including resource address and missing tag name
- [x] T009 [P] Create `policies/naming.rego` — OPA/Conftest policy enforcing naming convention `{project}-{environment}-{resource-type}-{descriptor}` against plan JSON for enforced Azure resource types
- [x] T010 Verify `jmckenzie17/homeschoolio-shared-actions` repository exists and contains `.github/workflows/` directory; confirm `semver-release.yml` is present at `main`
- [x] T011 [P] Create `homeschoolio-shared-workflows/.github/workflows/validate.yml` — `workflow_call` reusable workflow: installs OpenTofu + Terragrunt, runs `terragrunt run-all fmt --check` and `terragrunt run-all validate`; inputs: `opentofu-version`, `terragrunt-version`; outputs: `validation-passed`
- [x] T012 [P] Create `homeschoolio-shared-workflows/.github/workflows/test.yml` — `workflow_call` reusable workflow: downloads plan artifact, runs tfsec (static HCL, `--minimum-severity HIGH`), Checkov (plan JSON), and Conftest (custom policies with `--output github`); uploads SARIF; outputs: `tests-passed`
- [x] T013 [P] Create `homeschoolio-shared-workflows/.github/workflows/plan.yml` — `workflow_call` reusable workflow: detects changed environment roots via `tj-actions/changed-files`, runs `terragrunt run-all plan` + `show -json` per root, posts plan summary as PR comment, uploads plan JSON artifact; outputs: `affected-roots`, `has-destructive-ops`, `plan-artifact`
- [x] T014 [P] Create `homeschoolio-shared-workflows/.github/workflows/apply.yml` — `workflow_call` reusable workflow: accepts `target-environment` input and Azure OIDC credential secrets, runs pre-apply plan verification then `terragrunt run-all apply -auto-approve`; outputs: `applied-sha`
- [x] T015 Push `homeschoolio-shared-workflows/` contents to `jmckenzie17/homeschoolio-shared-actions` (or confirm validate/test/plan/apply workflows are already present there) and create Git tag `v1.0.0`

**Checkpoint**: `jmckenzie17/homeschoolio-shared-actions` at `v1.0.0` with all 5 workflows; policies written. User story work can begin.

---

## Phase 3: User Story 1 — PR Triggers CI Pipeline Automatically (Priority: P1) 🎯 MVP

**Goal**: Every PR targeting `main` automatically runs validate → test → plan and posts
results to the PR checks panel within 5 minutes. Merge is blocked until all pass.
Destructive operations must be explicitly acknowledged in the PR description.

**Independent Test**: Open a PR with a trivial `.hcl` change; verify CI triggers within
2 minutes, all three check stages appear in the GitHub PR checks panel, and the merge
button is blocked until they pass.

### Implementation for User Story 1

- [x] T016 [US1] Create `.github/workflows/ci.yml` — caller workflow triggered on `pull_request` (opened, synchronize, reopened) targeting `main`; jobs: `validate` → `test` → `plan` (each using `needs:`), all calling `jmckenzie17/homeschoolio-shared-actions` workflows at pinned `${{ env.SHARED_WORKFLOWS_VERSION }}`; `destructive-op-gate` job checks PR body for `- [x] I acknowledge destructive operations` when `has-destructive-ops == 'true'`
- [x] T017 [US1] Configure GitHub branch protection on `main` via repository Settings: require status checks `validate`, `test`, `plan` to pass; require at least 1 PR review approval; document steps in `specs/001-terraform-cicd-pipelines/quickstart.md`
- [x] T018 [US1] Update `specs/001-terraform-cicd-pipelines/quickstart.md` — add US1 validation steps: open a test PR, verify CI triggers, read check results in PR panel, verify merge is blocked, fix a violation to unblock

**Checkpoint**: US1 complete — PRs get automatic CI results and merge is gated.

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
- [x] T021 [P] [US2] Add `policies/` directory to Conftest invocation in `homeschoolio-shared-workflows/.github/workflows/test.yml` if not already wired: confirm `conftest test tfplan.json -p policies/ --all-namespaces --output github` is the exact command used

**Checkpoint**: US1 + US2 complete — CI both triggers automatically and surfaces actionable test failures.

---

## Phase 5: User Story 3 — Release Promotes Infrastructure Through Environments (Priority: P2)

**Goal**: When a GitHub release is published (triggered by qualifying conventional commits
merged to `main`), the CD pipeline auto-applies to `dev`; staging and production promotion
are available via manual trigger with GitHub environment protection gates.

**Independent Test**: Merge a `feat:` commit; verify the release workflow creates a GitHub
release, the `dev-apply` job triggers on that release event within 5 minutes. Trigger staging
promotion; verify it runs only after `dev` succeeds. Trigger production promotion; verify the
GitHub environment gate (defined in `apply.yml`) pauses for reviewer approval before applying.

### Implementation for User Story 3

- [x] T022 [US3] Configure three GitHub environments in repository Settings → Environments: `dev` (no protection), `staging` (no protection), `production` (required reviewers: 1+, restrict deployment branch to `main`); document steps in `specs/001-terraform-cicd-pipelines/quickstart.md`
- [x] T023 [US3] Add environment-scoped Azure OIDC secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) scoped per environment (no prefix needed) in GitHub Settings; document in `specs/001-terraform-cicd-pipelines/quickstart.md`
- [x] T024 [US3] Create `.github/workflows/cd.yml` — caller workflow triggered on `release: published`; `dev-apply` job calls `apply.yml`; `staging-apply` (`needs: dev-apply`, `workflow_dispatch`) calls `apply.yml`; `production-apply` (`needs: staging-apply`, `workflow_dispatch`) calls `apply.yml` — each passes unprefixed Azure OIDC secrets; `environment:` gate declared inside `apply.yml` (not on caller)
- [x] T024a [US3] Update `homeschoolio-shared-workflows/.github/workflows/apply.yml` — add `environment: ${{ inputs.target-environment }}` on the job definition; push updated workflow to `jmckenzie17/homeschoolio-shared-actions` and tag `v1.0.1`; bump `SHARED_WORKFLOWS_VERSION` to `v1.0.1` in `ci.yml` and `cd.yml`
- [x] T025 [US3] Update `specs/001-terraform-cicd-pipelines/quickstart.md` — add CD validation steps: verify dev auto-apply after release event, how to trigger staging/production via `workflow_dispatch`, how to approve the production environment gate

**Checkpoint**: US3 complete — full dev → staging → production promotion chain with environment gates triggered by release event.

---

## Phase 6: User Story 4 — Conventional Commits Trigger Semantic Version Release (Priority: P2)

**Goal**: Merging a PR with qualifying conventional commits (`feat:`, `fix:`,
`BREAKING CHANGE`) to `main` automatically creates a semver Git tag (e.g., `v1.2.3`)
and updates the floating major pointer (`v1`) within 2 minutes, using
`jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml`.

**Independent Test**: Merge a PR with commit message `feat: add vpc module`; verify Git
tag `v{NEXT_MINOR}` and updated `v{MAJOR}` pointer appear within 2 minutes. Merge a
`chore:` PR and verify no new tag is created.

### Implementation for User Story 4

- [x] T026 [US4] Add `CONTRIBUTING.md` at repo root documenting conventional commit format: `feat:` (minor bump), `fix:` (patch bump), `chore:`/`docs:` (no release), `BREAKING CHANGE` footer (major bump); include examples for infrastructure changes
- [x] T027 [US4] Create `.github/workflows/release.yml` — caller workflow triggered on `push` to `main`; calls `jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml@main` with `release-branch: main`, `tag-prefix: "v"`, `secrets: inherit`
- [x] T028 [US4] Update `specs/001-terraform-cicd-pipelines/quickstart.md` — add semver validation steps: merge a `feat:` commit, verify tag created; merge a `chore:` commit, verify no tag; reference a tag from a downstream `terragrunt.hcl` source

**Checkpoint**: US4 complete — semantic version tags created automatically by conventional commits.

---

## Phase 7: User Story 5 — Shared Workflows Reused from jmckenzie17/homeschoolio-shared-actions (Priority: P3)

**Goal**: All CI/CD pipeline logic lives in `jmckenzie17/homeschoolio-shared-actions`
at a pinned semver tag. No workflow logic is duplicated in this repo's
`.github/workflows/` files. Upgrading requires only a single-line version bump PR.

**Independent Test**: Update a step in `homeschoolio-shared-actions` (e.g., change
tfsec severity), publish tag `v1.0.1`, bump `SHARED_WORKFLOWS_VERSION` in this repo
from `v1.0.0` to `v1.0.1`, open and merge a PR; verify new behavior takes effect with
no other changes to this repo.

### Implementation for User Story 5

- [x] T029 [US5] Audit `.github/workflows/ci.yml`, `cd.yml`, and `release.yml`: confirm all substantive logic is in shared workflows; only `uses:`, `with:`, `secrets:`, `needs:`, `environment:`, and `env:` declarations are permitted locally; fix any inline logic found
- [x] T030 [US5] Verify `SHARED_WORKFLOWS_VERSION` env var is defined at workflow level in `ci.yml` and `cd.yml` so all `uses:` references pin to the same tag in one place; confirm `release.yml` uses `@main` (intentional — `semver-release.yml` is in the same shared-actions repo and uses its own release process)
- [x] T031 [US5] Update `specs/001-terraform-cicd-pipelines/quickstart.md` — document shared workflow upgrade process: check `jmckenzie17/homeschoolio-shared-actions` releases, open PR bumping `SHARED_WORKFLOWS_VERSION`, verify CI passes, merge

**Checkpoint**: All 5 user stories complete — full CI/CD pipeline operational.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, documentation, and compliance items that span all stories.

- [x] T032 [P] Update `CHANGELOG.md` with a `## [1.0.0]` entry documenting the pipeline release, shared workflow versions used, and link to `jmckenzie17/homeschoolio-shared-actions` tag
- [x] T033 [P] Verify all Azure infrastructure referenced by the pipeline (state storage accounts, Key Vault) carries required tags (`Project`, `Environment`, `ManagedBy = "opentofu"`, `Owner`) — add or extend `policies/tags.rego` if any resource types are not covered
- [x] T034 Add Infracost workflow to `jmckenzie17/homeschoolio-shared-actions` as `cost.yml` (`workflow_call`), post cost delta as PR comment; update `ci.yml` to call it; satisfies constitution Principle VI deferred item; bump shared-actions tag to `v1.1.0` and update `SHARED_WORKFLOWS_VERSION`
- [x] T035 [P] Update `specs/001-terraform-cicd-pipelines/checklists/requirements.md` — mark all items complete after end-to-end quickstart validation
- [ ] T036 Run full `specs/001-terraform-cicd-pipelines/quickstart.md` validation checklist end-to-end; confirm all acceptance criteria pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately; T003–T007 all parallel
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories; T011–T014 parallel after T010
- **US1 (Phase 3)**: Depends on Phase 2 complete (shared workflows at v1.0.0 + policies)
- **US2 (Phase 4)**: Depends on Phase 2; runs parallel to US1 (different files)
- **US3 (Phase 5)**: T022–T023 can start after Phase 2; T024 depends on US1 (`ci.yml` must exist)
- **US4 (Phase 6)**: Depends on Phase 2; T027 already done; T026/T028 independent
- **US5 (Phase 7)**: Depends on US1–US4 all complete (audit requires all workflows exist)
- **Polish (Phase 8)**: Depends on US1–US5 complete

### User Story Dependencies

- **US1 (P1)**: After Foundational — no story dependencies
- **US2 (P1)**: After Foundational — parallel with US1
- **US3 (P2)**: T022–T023 after Foundational; T024 after US1
- **US4 (P2)**: After Foundational; independent of US1–US3
- **US5 (P3)**: After US1–US4 all complete

### Parallel Opportunities

- T003–T007 (Setup): all parallel
- T011–T014 (Shared workflows): all parallel after T010
- T016 (US1) + T019 (US2) + T022–T023 (US3 config): parallel after Foundational
- T026 + T027 (US4): parallel
- T032 + T033 + T035 (Polish): parallel

---

## Parallel Example: Foundational Phase

```bash
# After T010 (confirm shared-actions repo), launch all shared workflow files in parallel:
Task: "Create validate.yml in homeschoolio-shared-workflows/"   # T011
Task: "Create test.yml in homeschoolio-shared-workflows/"       # T012
Task: "Create plan.yml in homeschoolio-shared-workflows/"       # T013
Task: "Create apply.yml in homeschoolio-shared-workflows/"      # T014
```

---

## Implementation Strategy

### MVP First (US1 + US2 Only)

1. Complete Phase 1: Setup (T001–T007) ✅
2. Complete Phase 2: Foundational (T008–T015) — policies done ✅, push shared workflows + tag (T015)
3. Complete Phase 3: US1 — `ci.yml` done ✅, branch protection (T017), quickstart (T018)
4. Complete Phase 4: US2 — policies verified ✅, README (T020), Conftest wire-up check (T021)
5. **STOP and VALIDATE**: Open a test PR, introduce a tag violation, confirm CI fails with actionable output; fix, confirm pass; verify merge blocked until pass
6. MVP deployed: every PR has automated safety gates

### Incremental Delivery

1. Setup + Foundational → Shared workflow library live
2. US1 + US2 → CI pipeline on all PRs (MVP ✅)
3. US3 → Full environment promotion chain
4. US4 → Automated semver releases via conventional commits
5. US5 → Shared workflow reuse audited and documented
6. Polish → Infracost, CHANGELOG, checklist complete

---

## Notes

- `[P]` tasks operate on different files with no unresolved dependencies — safe to run concurrently
- `[Story]` label maps each task to its user story for traceability to spec.md
- Shared-actions repo: `jmckenzie17/homeschoolio-shared-actions` (confirmed from clarification)
- `semver-release.yml` already exists in shared-actions — no custom tag workflow needed
- Caller workflows MUST remain thin (no inline logic per US5 / constitution Principle III)
- `release.yml` pins to `@main` for `semver-release.yml` — intentional since that workflow manages its own releases in the shared-actions repo
- Azure credentials: use OIDC workload identity federation (not long-lived service principal secrets)
- T015 is a manual step: push shared workflow files and tag `v1.0.0` on `jmckenzie17/homeschoolio-shared-actions`
