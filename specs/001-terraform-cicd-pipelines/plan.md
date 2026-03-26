# Implementation Plan: OpenTofu/Terragrunt CI/CD Pipelines with Semantic Versioning

**Branch**: `001-terraform-cicd-pipelines` | **Date**: 2026-03-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-terraform-cicd-pipelines/spec.md`

## Summary

Implement automated CI/CD pipelines for OpenTofu/Terragrunt infrastructure on Microsoft Azure
using reusable GitHub Actions workflows from `jmckenzie17/homeschoolio-shared-actions`, pinned
to semver tags. The CI pipeline (validate → test → plan) runs on every PR. The release workflow
creates a GitHub release on qualifying conventional commit merges to `main`. The CD pipeline
triggers on the GitHub release published event and auto-applies to `dev`; staging and production
promotion are available via manual `workflow_dispatch`. Semantic version tags are created
automatically via the existing `semver-release.yml` shared workflow.

## Technical Context

**Language/Version**: HCL (OpenTofu ≥ 1.6) + Terragrunt ≥ 0.56
**Primary Dependencies**: `opentofu/setup-opentofu@v1`, `actions/cache@v4`, `tj-actions/changed-files@v44`, `cycjimmy/semantic-release-action@v6` (via shared workflow), tfsec, Checkov, OPA/Conftest
**Storage**: Azure Storage Account `homeschooliostfstate` + Blob containers per environment (`homeschoolio-{env}-infra-tfstate`); resource group `homeschoolio-shared-rg-tfstate`
**Testing**: tfsec (static HCL), Checkov (plan JSON), OPA/Conftest (custom policies) — no unit test framework
**Target Platform**: GitHub Actions (ubuntu-latest runners); Microsoft Azure cloud
**Project Type**: Infrastructure-as-code repository with CI/CD automation
**Performance Goals**: CI completes within 5 minutes; CD applies to dev within 5 minutes of release event
**Constraints**: All pipeline logic in `jmckenzie17/homeschoolio-shared-actions`; caller workflows must be thin; OIDC only (no long-lived credentials); `environment:` must be declared inside reusable workflow jobs, not on caller jobs
**Scale/Scope**: 3 environment tiers (dev, staging, production); multiple Terragrunt roots per env

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code | ✅ PASS | All resources in HCL; pipeline enforces this via CI checks |
| II. Environment Parity & Promotion | ✅ PASS | dev → staging → production chain enforced in `cd.yml`; no skipping |
| III. Immutable Versioning | ✅ PASS | Shared workflows pinned to semver tags; `release.yml` creates semver tags + GitHub release on merge |
| IV. Plan Before Apply | ✅ PASS | `plan.yml` runs on every PR; `apply.yml` runs pre-apply plan verification |
| V. State Isolation & Locking | ✅ PASS | Azure Storage Account `homeschooliostfstate` with Blob lease locking; one container per env |
| VI. Observability & Auditability | ✅ PASS | SARIF uploads, PR comments, pipeline traceable to commit SHA and PR; Infracost deferred |
| Cloud Provider Standards | ✅ PASS | Azure explicitly declared; ARM_ env vars; OIDC with AzureAD federation via `justin-mckenzie-app` |

**Post-Phase-1 Re-check**: All gates still PASS. No violations introduced by design phase.

## Project Structure

### Documentation (this feature)

```text
specs/001-terraform-cicd-pipelines/
├── plan.md              # This file
├── research.md          # Technical decisions
├── data-model.md        # Key entities
├── quickstart.md        # Validation steps per user story
├── contracts/           # Workflow interface contracts
│   ├── ci-workflow-inputs.md
│   ├── cd-workflow-inputs.md
│   └── shared-workflow-interface.md
└── tasks.md             # Implementation task list
```

### Source Code (repository root)

```text
.github/
└── workflows/
    ├── ci.yml           # PR trigger: validate → test → plan → destructive-op gate
    ├── cd.yml           # Release trigger: dev (auto) → staging → production (gated)
    └── release.yml      # Semantic version release via conventional commits → GitHub release

homeschoolio-shared-workflows/
└── .github/
    └── workflows/       # Pushed to jmckenzie17/homeschoolio-shared-actions@v1.0.1
        ├── validate.yml # Reusable: fmt check + validate
        ├── test.yml     # Reusable: tfsec + Checkov + Conftest
        ├── plan.yml     # Reusable: changed-root detection + plan + PR comment
        └── apply.yml    # Reusable: environment gate + pre-apply plan + terragrunt apply

modules/
└── example/
    └── version.tf       # Module version template: locals { module_version = "1.0.0" }

environments/
├── dev/
├── staging/
└── production/

policies/
├── tags.rego            # Required Azure tag compliance
├── naming.rego          # Resource naming convention enforcement
└── README.md            # Policy documentation

.opentofu-version        # 1.6.2
.terragrunt-version      # 0.56.3
.gitignore
CHANGELOG.md
CONTRIBUTING.md          # Conventional commit guidelines
```

**Structure Decision**: Infrastructure-as-code repository with GitHub Actions CI/CD. All
pipeline logic lives in `jmckenzie17/homeschoolio-shared-actions`; this repo's `.github/workflows/`
contains only thin caller workflows. CD triggers on `release: published` (not `push to main`);
the `environment:` gate lives inside `apply.yml` in the shared-actions repo (required by GitHub —
`environment:` is not permitted on caller jobs that use `uses:`).

## Complexity Tracking

No constitution violations — table not required.
