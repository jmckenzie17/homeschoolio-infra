# Feature Specification: OpenTofu/Terragrunt CI/CD Pipelines with Semantic Versioning

**Feature Branch**: `001-terraform-cicd-pipelines`
**Created**: 2026-03-26
**Status**: Draft
**Input**: User description: "setup ci cd pipelines for terraform/terragrunt using semantic versioning shared workflows from the homeschoolio-shared-workflows repo. include tests in the ci pipeline"

## Clarifications

### Session 2026-03-26

- Q: Which IaC runtime should the pipeline use — Terraform or OpenTofu? → A: OpenTofu
- Q: How should this repo pin its references to shared workflows in `homeschoolio-shared-workflows`? → A: Pin to a semver tag (e.g., `@v1.2.0`); upgrades via explicit PR
- Q: What mechanism grants explicit approval for production promotion? → A: GitHub environment protection rules with required reviewers
- Q: How are engineers notified of pipeline failures? → A: GitHub native only (failed check status + GitHub email notifications; no external channels)
- Q: Which shared workflow handles module semantic versioning and release tagging? → A: `jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml` — uses semantic-release driven by conventional commits; outputs `release-created`, `tag-name`, `major-tag`
- Q: What event triggers the CD pipeline? → A: GitHub release published event (not push to main); CD triggers when a semver release is created by the release workflow

### Session 2026-03-27

- Q: Should the CD workflow trigger on all published releases or only releases whose tag matches a specific pattern? → A: Only releases whose tag matches `v[0-9]+.[0-9]+.[0-9]+` (stable semver only; excludes pre-releases and manually created tags)
- Q: Should the CD workflow trigger on draft releases or only published (non-draft) releases? → A: Only published (non-draft) releases
- Q: How should the CD pipeline handle a second release published while a prior CD run is still in progress? → A: Queue — allow one active run; the next release waits until the current run completes (no cancel-in-progress)
- Q: Should the CD pipeline apply all Terragrunt environment roots or only roots whose files changed in the release? → A: Apply all environment roots unconditionally on every release
- Q: If `staging` promotion is never triggered before the next release fires, how should `dev` behave? → A: New release overwrites `dev` again unconditionally; no expiry, staleness tracking, or blocking of subsequent CD runs

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Engineer Opens a PR Against an Infrastructure Change (Priority: P1)

An engineer makes a change to an OpenTofu module or Terragrunt configuration, opens a
pull request, and receives automated feedback from the CI pipeline before any reviewer
looks at the code.

**Why this priority**: This is the core safety gate. Every subsequent story depends on
CI running reliably on every PR. Without it, the team cannot safely review or merge
infrastructure changes.

**Independent Test**: Create a PR with a trivial Terragrunt config change; verify that
the CI pipeline triggers automatically, runs all checks, and posts a status report back
to the PR without any manual intervention.

**Acceptance Scenarios**:

1. **Given** an engineer opens a PR with an OpenTofu/Terragrunt change, **When** the PR
   is created or updated, **Then** the CI pipeline runs automatically within 2 minutes
   and posts a pass/fail status to the PR.
2. **Given** the CI pipeline runs on a PR, **When** the pipeline completes, **Then** the
   results of validation, testing, and plan generation are all visible in the PR checks
   panel without navigating away.
3. **Given** a PR where the CI pipeline has not yet passed, **When** a reviewer attempts
   to approve and merge, **Then** the merge is blocked until all required checks pass.

---

### User Story 2 - CI Pipeline Detects and Reports Infrastructure Test Failures (Priority: P1)

The CI pipeline runs automated tests against infrastructure changes and surfaces failures
clearly so engineers know exactly what broke and why before the change reaches any
environment.

**Why this priority**: Tests are the primary mechanism for catching misconfigurations
and policy violations early. Equal priority to US1 because CI without tests provides
incomplete safety coverage.

**Independent Test**: Introduce a deliberate policy violation (e.g., a resource missing
required tags) into a test branch; verify CI fails with a clear error message identifying
the violation, and that fixing it causes CI to pass.

**Acceptance Scenarios**:

1. **Given** a PR contains a resource missing required tags, **When** CI runs, **Then**
   the test stage fails and the failure message identifies the specific resource and
   missing tag.
2. **Given** all infrastructure tests pass, **When** CI runs, **Then** the test stage
   reports success and does not block the PR.
3. **Given** a test failure occurs, **When** an engineer reads the CI output, **Then**
   they can identify the failing rule and the file/resource causing it without opening
   any external system.

---

### User Story 3 - Engineer Merges to Main and Infrastructure Promotes Through Environments (Priority: P2)

After CI passes and a PR is merged to `main`, the release workflow creates a semver Git
tag and GitHub release. The CD pipeline triggers on that release event and automatically
applies to `dev`; `staging` and `production` promotion are available via manual trigger.

**Why this priority**: Closes the loop from code review to live infrastructure. Builds
on US1/US2 (CI must pass before merge is possible) and US4 (release event is the CD trigger).

**Independent Test**: Merge a PR with a qualifying conventional commit; verify the release
workflow creates a GitHub release, the CD pipeline triggers on that release event, and
applies to `dev` automatically within 5 minutes.

**Acceptance Scenarios**:

1. **Given** a GitHub release is published (triggered by a qualifying conventional commit
   merged to `main`), **When** the release event fires, **Then** the CD pipeline
   automatically applies the change to `dev` within 5 minutes.
2. **Given** the `dev` apply succeeds, **When** an engineer triggers the `staging`
   promotion, **Then** a plan is generated, reviewed, and the apply runs in `staging`
   before any production change.
3. **Given** the `staging` apply succeeds, **When** an engineer triggers the `production`
   promotion, **Then** the pipeline pauses at a GitHub environment protection gate and
   applies to production only after a designated reviewer approves via the Actions UI.
4. **Given** any apply fails in any environment, **When** the failure occurs, **Then**
   the pipeline stops, no further promotion occurs, and the failure is reported with
   enough detail for the engineer to diagnose and remediate.

---

### User Story 4 - Module Version Bump Triggers Semantic Version Release (Priority: P2)

When an OpenTofu module's version is incremented following semantic versioning rules,
the pipeline creates a versioned release artifact (a Git tag) automatically so
consuming environments can pin to the new version.

**Why this priority**: Semantic versioning is a key stated requirement. Without
automated release tagging, version management becomes manual and error-prone.

**Independent Test**: Bump a module's version in a PR; verify the pipeline creates the
corresponding Git tag on merge and that the tag is accessible for downstream consumers.

**Acceptance Scenarios**:

1. **Given** a PR merged to `main` contains a `feat:` commit, **When** the release
   pipeline runs, **Then** a new minor version tag (e.g., `v1.1.0`) and updated `v1`
   pointer tag are created within 2 minutes.
2. **Given** a PR merged to `main` contains only `fix:` commits, **When** the release
   pipeline runs, **Then** a new patch version tag (e.g., `v1.0.1`) is created.
3. **Given** a PR merged to `main` contains a `BREAKING CHANGE` footer, **When** the
   release pipeline runs, **Then** a new major version tag (e.g., `v2.0.0`) is created.
4. **Given** a PR merged to `main` contains only `chore:` or `docs:` commits with no
   releasable changes, **When** the release pipeline runs, **Then** no new tag is
   created and `release-created` output is `false`.
5. **Given** a version tag is created, **When** another team member references that
   tag in a module source, **Then** they receive the exact code at that version with
   no drift.

---

### User Story 5 - Shared Workflows Are Reused Across Repositories (Priority: P3)

CI/CD pipeline logic is defined once in `homeschoolio-shared-workflows` and referenced
from this repo, so updates to pipeline behavior propagate consistently without
copy-pasting workflow files.

**Why this priority**: Reduces maintenance burden and ensures consistency, but
delivering working pipelines in this repo first (US1–US4) is more immediately critical.

**Independent Test**: Update a shared workflow step; verify the change is automatically
reflected when the pipeline runs in this repo without any change to this repo's workflow
files.

**Acceptance Scenarios**:

1. **Given** a CI/CD step is defined in `homeschoolio-shared-workflows`, **When** this
   repo's pipeline runs, **Then** it executes the shared step without duplicating its
   definition locally.
2. **Given** a new semver tag is published in `homeschoolio-shared-workflows`, **When**
   an engineer updates the pinned tag reference in a PR to this repo, **Then** the
   updated shared workflow behavior is used from that point forward without duplicating
   any workflow logic locally.

---

### Edge Cases

- What happens when a `terragrunt plan` produces no diff (no-op change)? The pipeline
  MUST still complete successfully and report the no-op status clearly.
- What happens when an apply fails mid-way through a complex change? The pipeline MUST
  stop immediately, not attempt automatic rollback, and report the partial state clearly.
- What happens when a second release is published while a CD run is active? The second
  run MUST be queued (not cancelled) and execute after the active run completes; no
  release event MUST be silently dropped.
- What happens when the shared workflow repository is unavailable? The pipeline MUST
  fail with a clear error identifying the missing dependency.
- What happens when a PR includes multiple module version bumps? Each module MUST be
  tagged independently on merge.
- What happens when a plan generates a destructive operation (resource deletion or
  replacement)? The plan output MUST highlight destructive operations prominently and
  require explicit acknowledgment before the merge gate passes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The CI pipeline MUST trigger automatically on every pull request open,
  update, and reopen event targeting the `main` branch.
- **FR-002**: The CI pipeline MUST run validation checks confirming all Terragrunt
  configurations are syntactically correct using OpenTofu.
- **FR-003**: The CI pipeline MUST execute automated infrastructure tests (policy-as-code
  checks, tag compliance, security scanning) and report pass/fail per test.
- **FR-004**: The CI pipeline MUST generate a `terragrunt plan` (backed by OpenTofu) for
  every changed environment root and publish the plan output as a PR artifact or comment.
- **FR-005**: The CI pipeline MUST block PR merge if any required check (validation,
  tests, plan) fails.
- **FR-006**: The CI pipeline MUST highlight destructive operations in the plan output
  and require the PR author to explicitly acknowledge them before the merge gate clears.
- **FR-007**: The CD pipeline MUST trigger automatically on a GitHub `release: published`
  event (non-draft only) whose tag matches the pattern `v[0-9]+.[0-9]+.[0-9]+` (stable
  semver only; draft releases, pre-release tags, and manually created tags MUST NOT
  trigger the CD pipeline) and apply changes to `dev`, preceded by a passing plan. The
  release is created by the release workflow when qualifying conventional commits are
  merged to `main`.
- **FR-007b**: On each CD trigger, the pipeline MUST run plan and apply against all
  Terragrunt environment roots unconditionally (no changed-files filtering); this
  ensures consistent environment state regardless of which files were modified in the
  release.
- **FR-007a**: The CD pipeline MUST use a GitHub Actions concurrency group scoped to the
  CD workflow with `cancel-in-progress: false` so that a second release published while
  a prior CD run is active is queued and executed after the active run completes; no
  release MUST be silently dropped.
- **FR-008**: The CD pipeline MUST require a manual trigger for `staging` promotion and
  MUST NOT apply to `staging` until the `dev` apply succeeds.
- **FR-009**: The CD pipeline MUST require a manual trigger with explicit approval for
  `production` promotion via GitHub environment protection rules (required reviewers)
  and MUST NOT apply to `production` until the `staging` apply succeeds.
- **FR-010**: The pipeline MUST create a versioned Git tag on every merge to `main`
  that contains qualifying conventional commits (`feat:` → minor, `fix:` → patch,
  `BREAKING CHANGE` footer → major), using the shared
  `jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml`
  workflow; the tag format is `v{MAJOR.MINOR.PATCH}` with a floating `v{MAJOR}`
  pointer tag updated on each release.
- **FR-011**: Pipeline workflow logic MUST be sourced from `homeschoolio-shared-workflows`
  at a pinned semver tag and MUST NOT be duplicated inline in this repository's workflow
  files; version upgrades MUST be performed via an explicit PR updating the pinned tag.
- **FR-012**: The pipeline MUST run the same CI checks on `main` after every merge to
  ensure the branch remains in a deployable state.
- **FR-013**: All pipeline runs MUST be traceable to the triggering commit SHA and PR
  number in their logs.
- **FR-014**: Pipeline failure notifications MUST be delivered exclusively via GitHub
  native check status and GitHub's built-in email notification system; no external
  notification channels (e.g., Slack, PagerDuty) are required.

### Key Entities

- **Pipeline Run**: A single execution of CI or CD, associated with a commit SHA, PR
  number, branch, and outcome (pass/fail/cancelled).
- **Environment Root**: A Terragrunt configuration directory representing one environment
  tier (dev, staging, production) for a given infrastructure domain.
- **Module Version**: A `MAJOR.MINOR.PATCH` string declared within an OpenTofu module,
  paired with a corresponding Git tag on release.
- **Plan Artifact**: The output of a `terragrunt plan` (OpenTofu-backed) execution,
  stored and linked to the PR for reviewer inspection.
- **Shared Workflow**: A reusable pipeline definition hosted in `homeschoolio-shared-workflows`
  encapsulating a discrete CI/CD step (validate, test, plan, apply, tag).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of PRs targeting `main` automatically receive CI pipeline results
  within 5 minutes of the triggering event, with zero manual initiation required.
- **SC-002**: Zero infrastructure changes reach `dev` without first passing all CI
  checks (validation, tests, plan review gate).
- **SC-003**: Zero infrastructure changes reach `staging` or `production` without a
  prior successful apply in the preceding environment tier.
- **SC-004**: 100% of merged PRs that include a module version bump result in a
  corresponding Git tag within 2 minutes of merge.
- **SC-005**: Engineers can identify the root cause of a CI failure solely from the
  pipeline output, without accessing any external system, for any single-rule violation.
- **SC-006**: Shared workflow upgrades require a single-line version bump PR in this
  repo; no workflow logic needs to be copied or re-implemented locally.

## Assumptions

- The CI/CD platform is GitHub Actions; `homeschoolio-shared-workflows` is a GitHub
  repository containing reusable workflow files.
- The IaC runtime is **OpenTofu** (formerly referred to as "Terraform" in the original
  description); Terragrunt wraps OpenTofu for DRY environment composition.
- The three environment tiers are `dev`, `staging`, and `production`; environment roots
  are organized under `environments/{env}/` in this repo.
- OpenTofu modules under `modules/` are versioned independently; each module maintains
  its own `MAJOR.MINOR.PATCH` version string.
- Infrastructure tests are policy-as-code checks that run against the plan output or
  static HCL without requiring a live cloud environment.
- Remote state backend is Azure Storage Account + Blob container with lease-based
  locking per constitution Principle V; the pipeline consumes existing backend
  configuration without setting it up.
- Azure credentials for plan and apply steps (e.g., OIDC workload identity or
  service principal) are stored as GitHub environment secrets and injected at
  runtime; secret management is out of scope.
- Destructive-operation acknowledgment is implemented as a PR description checkbox or
  label convention.
- Each GitHub release represents the full desired state of the repository; a new release
  supersedes any pending unapplied state in `dev`. There is no expiry, staleness alert,
  or gate blocking a new CD run if a prior `staging` promotion was never triggered.
- Semantic versioning is driven by conventional commits (`feat:`, `fix:`,
  `BREAKING CHANGE`) parsed by `semantic-release` via the shared
  `jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml`
  workflow; no manual `version.tf` file bumping is required.
