# Implementation Plan: Terraform Infrastructure Destroy Workflow

**Branch**: `004-terraform-destroy-workflow` | **Date**: 2026-03-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-terraform-destroy-workflow/spec.md`

## Summary

Create a `destroy.yml` GitHub Actions workflow that manually destroys all Terragrunt-managed infrastructure for a selected environment (`dev`, `staging`, or `production`). The workflow delegates to the `destroy.yml` reusable shared workflow in `jmckenzie17/homeschoolio-shared-actions@v1.5.0`, mirroring how `cd.yml` delegates applies — one per-environment job gated by an `if: inputs.environment == '<env>'` condition. The shared workflow handles confirmation gating, OIDC auth, `terragrunt run-all destroy`, provider caching, and job summary.

## Technical Context

**Language/Version**: YAML (GitHub Actions workflow syntax)
**Primary Dependencies**: `jmckenzie17/homeschoolio-shared-actions/.github/workflows/destroy.yml@v1.5.0`; existing secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TF_VAR_PG_ADMIN_PASSWORD`, `GITHUB_TOKEN`
**Storage**: Azure Blob Storage (`homeschooliostfstate`) — remote state backend, no new storage
**Testing**: Manual workflow trigger against `dev` environment; no automated test harness
**Target Platform**: GitHub Actions (ubuntu-latest runner)
**Project Type**: CI/CD workflow (YAML)
**Performance Goals**: Human interaction time under 5 minutes (resource deletion time excluded)
**Constraints**: Must not run automatically; must abort without confirmation; must not affect non-selected environments
**Scale/Scope**: Single workflow file; 4 Terragrunt roots × 3 environments

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Infrastructure as Code | PASS | Workflow orchestrates `terragrunt destroy`; no manual cloud resource changes |
| II. Environment Parity & Promotion | PASS | Workflow is environment-scoped; no cross-environment side effects |
| III. Immutable Versioning | PASS | No module version changes; workflow pins action versions |
| IV. Plan Before Apply | NOTE | Destroy bypasses the plan-review gate by design. This is an explicit, manual, confirmation-gated operation — not a standard promotion. Documented in Complexity Tracking. |
| V. State Isolation & Locking | PASS | Reuses existing per-root state containers; concurrency group prevents concurrent apply/destroy |
| VI. Cost Consciousness & Observability | PASS | Destroy reduces cost; workflow emits audit log via GitHub Actions step summary |

## Project Structure

### Documentation (this feature)

```text
specs/004-terraform-destroy-workflow/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
.github/
└── workflows/
    ├── ci.yml           # Existing — unchanged
    ├── cd.yml           # Existing — unchanged
    └── destroy.yml      # NEW — manual destroy workflow
```

**Structure Decision**: Single new workflow file alongside existing CI/CD workflows. No new modules, environments, or source directories required.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Destroy without plan review (Principle IV) | Destroy is an explicitly manual, confirmation-gated operation. A plan review gate for destroy would block the operation in emergencies and add friction without safety benefit — the confirmation checkbox is the equivalent gate. | Requiring a plan PR before destroy would mean opening a PR, waiting for CI, merging, and then triggering destroy — unworkable for teardown scenarios |
