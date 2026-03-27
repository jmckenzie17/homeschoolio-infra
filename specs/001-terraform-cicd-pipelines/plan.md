# Implementation Plan: Terraform/Terragrunt CI/CD Pipelines

**Branch**: `001-terraform-cicd-pipelines` | **Date**: 2026-03-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-terraform-cicd-pipelines/spec.md`

## Summary

Implement automated CI/CD pipelines for an OpenTofu/Terragrunt monorepo targeting Microsoft Azure.
CI runs on every PR: validate → test (tfsec, Checkov, OPA/Conftest) → plan (all environments) →
destructive-op gate. CD triggers on GitHub release published (created by `release.yml` via
semantic-release): auto-apply to `dev`, then manual-dispatch promotion to `staging` and
`production`. Environment protection is enforced inside the shared `apply.yml` reusable workflow
(not on the caller job). All shared workflow calls reference exact semver tags via the single
`SHARED_WORKFLOWS_VERSION` env var.

## Technical Context

**Language/Version**: HCL (OpenTofu ≥ 1.6) + Terragrunt ≥ 0.56
**Primary Dependencies**: `opentofu/setup-opentofu@v1`, `actions/cache@v4`, tfsec, Checkov, Conftest, semantic-release
**Storage**: Azure Storage Account `homeschooliostfstate` (eastus) — containers: `homeschoolio-dev-infra-tfstate`, `homeschoolio-staging-infra-tfstate`, `homeschoolio-production-infra-tfstate`
**Testing**: tfsec (static HCL), Checkov (plan JSON), OPA/Conftest (custom policies in `policies/`)
**Target Platform**: GitHub Actions (ubuntu-latest runners), Azure
**Project Type**: CI/CD pipeline configuration (IaC)
**Performance Goals**: CI completes in < 10 minutes for typical PRs
**Constraints**: No Infracost; use lowest-cost Azure SKUs; POC SLA posture; `environment:` set inside `apply.yml` (not caller jobs); secrets unprefixed (environment-scoped)
**Scale/Scope**: 3 environment tiers (dev / staging / production), single infrastructure domain

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Infrastructure as Code | ✅ PASS | All resources in HCL; no manual changes |
| II. Environment Parity & Promotion | ✅ PASS | dev → staging → production promotion enforced in CD; each env has own state backend |
| III. Immutable Versioning | ✅ PASS | `SHARED_WORKFLOWS_VERSION: v1.2.0` pins all shared refs; no floating `@main` in CI/CD callers |
| IV. Plan Before Apply | ✅ PASS | CI generates plan artifact on every PR; destructive-op gate requires explicit PR acknowledgment |
| V. State Isolation & Locking | ✅ PASS | Azure Blob lease locking; one container per env; versioning enabled on storage account |
| VI. Cost Consciousness & Observability | ✅ PASS | No Infracost required; lowest-cost tier policy; tfsec/Checkov/Conftest run in CI; audit logs tied to commit SHA |

**Post-design re-check**: All gates still pass. `environment:` constraint moved into `apply.yml` to satisfy GitHub Actions schema. Secret names unprefixed (scoped per GitHub environment).

## Project Structure

### Documentation (this feature)

```text
specs/001-terraform-cicd-pipelines/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── ci-workflow.md
│   ├── cd-workflow.md
│   └── shared-workflow-interface.md
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
.github/
├── workflows/
│   ├── ci.yml           # PR + push-to-main validation pipeline
│   ├── cd.yml           # Release-triggered deployment pipeline
│   └── release.yml      # Semver release (calls shared semver-release.yml@main)
policies/
├── tags.rego            # OPA: required tag compliance
├── naming.rego          # OPA: resource naming convention
└── README.md
environments/
├── dev/                 # Terragrunt root (to be populated)
├── staging/             # Terragrunt root (to be populated)
└── production/          # Terragrunt root (to be populated)
modules/                 # Reusable OpenTofu modules
CHANGELOG.md
CONTRIBUTING.md
```

**Structure Decision**: IaC repository layout — workflows under `.github/workflows/`, OPA policies
under `policies/`, environment compositions under `environments/{env}/`, modules under `modules/`.
No traditional `src/` tree.

## Complexity Tracking

> No constitution violations requiring justification.
