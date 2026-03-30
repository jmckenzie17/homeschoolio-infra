# Implementation Plan: OpenTofu/Terragrunt CI/CD Pipelines with Semantic Versioning

**Branch**: `001-terraform-cicd-pipelines` | **Date**: 2026-03-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-terraform-cicd-pipelines/spec.md`

## Summary

Implement GitHub Actions CI/CD pipelines for this OpenTofu/Terragrunt infrastructure
repository. The CI pipeline runs on every PR (validate → plan → test → destructive-op
gate). The CD pipeline triggers on push to `main`, runs `semantic-release` to create a
semver Git tag/release, and automatically applies to the `dev` environment root when a
release is created. Staging and production promotion are out of scope for this feature.
All pipeline logic is sourced from reusable workflows in
`jmckenzie17/homeschoolio-shared-actions`, pinned to a semver tag.

**Current state**: Both `ci.yml` and `cd.yml` workflows already exist and are largely
correct. The plan identifies gaps relative to the spec and delivers the delta work
needed to reach full compliance.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6.2, pinned via `.opentofu-version`); Terragrunt
0.56.3 (pinned via `.terragrunt-version`); YAML (GitHub Actions workflow syntax)
**Primary Dependencies**: `jmckenzie17/homeschoolio-shared-actions` (shared reusable
workflows) pinned at `v1.3.6`; `actions/github-script@v8`; AzureRM provider `~> 3.0`;
`semantic-release` (invoked by shared semver-release workflow)
**Storage**: Azure Blob Storage (`homeschooliostfstate`, `eastus`) — remote state
backend; `homeschoolio-dev-infra-tfstate` container for `dev` environment root
**Testing**: OPA/Conftest (policies under `policies/`), tfsec, Checkov — all invoked by
the shared `test.yml` workflow; plan JSON artifact passed as input
**Target Platform**: GitHub Actions runners (ubuntu-latest); Azure (eastus)
**Project Type**: Infrastructure-as-code CI/CD pipeline (YAML + HCL)
**Performance Goals**: CI completes within 5 minutes of PR trigger (SC-001); CD applies
to `dev` within 5 minutes of merge (US3 independent test)
**Constraints**: OIDC/Workload Identity auth only (no long-lived service principal
secrets); `GITHUB_TOKEN` cannot trigger downstream workflow runs (GitHub security
restriction — mitigated by single `cd.yml` combining release + apply jobs)
**Scale/Scope**: 1 environment root in scope (`environments/dev/infra`); 1 module
(`modules/example`); 3 policy files (`policies/tags.rego`, `policies/naming.rego`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code | PASS | All resources in HCL; Terragrunt DRY wrappers; no manual changes |
| II. Environment Parity & Promotion | SCOPED — dev only | Staging/production promotion explicitly deferred to future feature per spec clarification 2026-03-30; `dev` environment root has its own state container; no tier-skipping is possible with dev-only scope |
| III. Immutable Versioning | PASS | Shared workflows pinned to `v1.3.6`; modules use `MAJOR.MINOR.PATCH`; semantic-release drives tagging |
| IV. Plan Before Apply | PASS | CI generates `terragrunt plan` artifact on every PR; plan reviewed before merge; destructive-op gate enforced |
| V. State Isolation & Locking | PASS | Azure Blob backend per environment root; Azure lease locking; no local state |
| VI. Cost Consciousness & Observability | PASS | All pipeline runs traceable to commit SHA; OPA/Checkov/tfsec in CI; no extra-cost tooling added |

**Constitution gate: PASS** (Principle II scoping is explicitly justified in spec.)

## Project Structure

### Documentation (this feature)

```text
specs/001-terraform-cicd-pipelines/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

No `contracts/` directory — this feature produces no public API, library interface, or
external-facing schema. Workflow YAML files are internal CI/CD configuration, not
contracts consumed by other systems.

### Source Code (repository root)

```text
.github/
└── workflows/
    ├── ci.yml           # PR pipeline: validate → plan → test → destructive-op gate
    └── cd.yml           # Push-to-main pipeline: release + dev-apply jobs

environments/
└── dev/
    └── infra/
        └── terragrunt.hcl  # Dev environment root (only root targeted by CD)

modules/
└── example/             # Deployed to dev; used to validate pipeline end-to-end
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── version.tf

policies/
├── tags.rego            # OPA: required tags (Project, Environment, ManagedBy, Owner)
└── naming.rego          # OPA: {project}-{environment}-{type}-{descriptor} pattern

.opentofu-version        # Pins OpenTofu 1.6.2
.terragrunt-version      # Pins Terragrunt 0.56.3
```

**Structure Decision**: Single flat layout with workflow YAML at `.github/workflows/`,
IaC source under `environments/` and `modules/`, policies under `policies/`. No
src/tests directories — this is a pure IaC + CI/CD pipeline feature, not an application.

## Complexity Tracking

No constitution violations requiring justification. Principle II scoping (dev-only) is
explicitly permitted by the spec clarification recorded 2026-03-30 and does not
constitute a violation — the principle's "no skipping" constraint is trivially satisfied
when only one tier is in scope.

## Gap Analysis: Existing Workflows vs. Spec

### ci.yml — current state vs. spec

| FR | Requirement | Current State | Gap |
|----|-------------|---------------|-----|
| FR-001 | Trigger on PR open/update/reopen to main only | `on: pull_request: branches: [main]` | COMPLIANT |
| FR-002 | Validate all Terragrunt roots | `validate` job via shared workflow | COMPLIANT |
| FR-003 | Run infrastructure tests (OPA, Checkov, tfsec) | `test` job via shared workflow | COMPLIANT |
| FR-004 | Generate plan and publish as PR artifact | `plan` job with `environments: "dev,staging,production"` | GAP: should be `"dev"` only per clarification |
| FR-005 | Block merge on failure | GitHub branch protection + required checks | COMPLIANT (requires branch protection config) |
| FR-006 | Destructive-op gate | `destructive-op-gate` job | COMPLIANT |
| FR-013 | Traceable to commit SHA and PR | Implicit in GitHub Actions context | COMPLIANT |
| FR-014 | Notifications via GitHub native only | No external integrations | COMPLIANT |

**CI gap**: `plan` job targets `environments: "dev,staging,production"` — should be `"dev"` only.

### cd.yml — current state vs. spec

| FR | Requirement | Current State | Gap |
|----|-------------|---------------|-----|
| FR-007 | Trigger on push to main; release + dev-apply in single workflow | `on: push: branches: [main]` + combined jobs | COMPLIANT |
| FR-007a | Queue concurrent runs (`cancel-in-progress: false`) | `concurrency: group: cd-deployment, cancel-in-progress: false` | COMPLIANT |
| FR-007b | Target dev root only | `dev-apply` targets `dev`; but `staging-apply` and `production-apply` jobs exist | GAP: staging/production jobs must be removed |
| FR-008 | Staging promotion out of scope | `staging-apply` job exists | GAP: remove `staging-apply` job |
| FR-009 | Production promotion out of scope | `production-apply` job exists | GAP: remove `production-apply` job |
| FR-010 | Semver tagging via shared workflow | `release` job via `semver-release.yml@v1.3.6` | COMPLIANT |
| FR-011 | All logic sourced from shared workflows at pinned tag | All `uses:` pinned to `v1.3.6` | COMPLIANT |

**CD gaps**:
1. `workflow_dispatch` input for staging/production promotion must be removed.
2. `staging-apply` and `production-apply` jobs must be removed.
3. `dev-apply` `if:` condition references `needs.release` — verify it remains correct after removing downstream jobs.

### Branch Protection / GitHub Settings (out-of-band)

The following must be configured in GitHub repository settings (not in YAML files):

- Branch protection rule on `main`: require status checks `Validate`, `Plan`, `Test`,
  `Destructive Operation Gate` (when applicable).
- Require PR before merging, require approvals ≥ 1.
- These are administrative settings, not implementable via workflow YAML.

## Phase 0: Research

See [research.md](research.md) for full findings. Key decisions:

| Decision | Rationale |
|----------|-----------|
| Single `cd.yml` (release + dev-apply combined) | Avoids `GITHUB_TOKEN` downstream event restriction; no PAT or additional token needed |
| Pin shared workflows to `v1.3.6` | Already established; upgrade via explicit PR per FR-011 |
| OPA/Conftest for policy-as-code | Already in place (`policies/` directory with `tags.rego`, `naming.rego`); shared `test.yml` consumes plan JSON artifact |
| `environments: "dev"` in CI plan job | Narrows plan scope to dev root; aligns with clarification that staging/production are out of scope |
| Queue CD runs (`cancel-in-progress: false`) | Ensures no release is silently dropped; matches FR-007a and clarification answer |
| OIDC Workload Identity auth | Secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` already in repo; no long-lived credentials |

## Phase 1: Design

### Data Model

See [data-model.md](data-model.md) for full entity definitions. Summary:

| Entity | Source of Truth | Notes |
|--------|----------------|-------|
| Pipeline Run | GitHub Actions run | Tied to commit SHA, PR number, branch, outcome |
| Environment Root | `environments/dev/infra/terragrunt.hcl` | Only `dev` root in scope |
| Module Version | `modules/example/version.tf` (`module_version = "1.0.0"`) | Semantic version string; updated via conventional commits |
| Plan Artifact | GitHub Actions artifact (`tfplan-json-{run_id}`) | JSON plan output; passed to `test.yml` |
| Shared Workflow | `jmckenzie17/homeschoolio-shared-actions@v1.3.6` | Pinned reusable workflows |
| Git Tag / Release | GitHub release created by `semver-release.yml` | Format `v{MAJOR.MINOR.PATCH}`; floating `v{MAJOR}` pointer |

### Interface Contracts

No external contracts — this feature produces GitHub Actions workflow YAML and Terragrunt
HCL configuration. These are internal CI/CD pipeline definitions consumed only by GitHub
Actions runners and the Terragrunt CLI. No public API surface is exposed.

The shared workflow interface (inputs/outputs/secrets) is owned by
`jmckenzie17/homeschoolio-shared-actions` and documented in [research.md](research.md).

### Concrete Changes Required

#### 1. `.github/workflows/ci.yml` — change `environments` input

```yaml
# Before
  plan:
    with:
      environments: "dev,staging,production"

# After
  plan:
    with:
      environments: "dev"
```

#### 2. `.github/workflows/cd.yml` — remove staging/production jobs and dispatch input

Remove:
- `workflow_dispatch` trigger block (entire `inputs:` section, or entire `workflow_dispatch:` key)
- `staging-apply` job
- `production-apply` job

Retain:
- `on: push: branches: [main]`
- `permissions`
- `concurrency` group (unchanged)
- `release` job (unchanged)
- `dev-apply` job (unchanged — already correctly targets `dev` and gates on `needs.release.outputs.release-created == 'true'`)

#### 3. Branch Protection (GitHub UI — not a workflow change)

Configure on `main`:
- Required status checks: `Validate`, `Plan`, `Test`, `Destructive Operation Gate`
- Require PR before merge
- Require at least 1 approval
- Do not allow bypassing required checks

### Quickstart

See [quickstart.md](quickstart.md) for developer onboarding guide.

## Post-Design Constitution Re-Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. IaC | PASS | No drift; all resources managed in HCL |
| II. Environment Parity | SCOPED (justified) | Dev-only scope is explicit and justified |
| III. Immutable Versioning | PASS | `v1.3.6` pin unchanged; semantic-release drives tags |
| IV. Plan Before Apply | PASS | CI generates plan on every PR; destructive-op gate in place |
| V. State Isolation | PASS | `homeschoolio-dev-infra-tfstate` container; Azure Blob locking |
| VI. Observability | PASS | All runs traceable to SHA; OPA/Checkov/tfsec block HIGH findings |

**Post-design gate: PASS**
