# Implementation Plan: OpenTofu/Terragrunt CI/CD Pipelines with Semantic Versioning

**Branch**: `001-terraform-cicd-pipelines` | **Date**: 2026-03-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-terraform-cicd-pipelines/spec.md`

## Summary

Implement GitHub Actions CI/CD pipelines for OpenTofu 1.6.2 / Terragrunt 0.56.3 infrastructure,
using reusable shared workflows pinned to semver tags from `jmckenzie17/homeschoolio-shared-actions`.
CI runs on every PR (validate → plan → test → destructive-op gate). CD triggers on GitHub
`release: published` events whose tag matches `v[0-9]+.[0-9]+.[0-9]+` (stable semver, non-draft,
non-prerelease), applies all environment roots to `dev` automatically, and gates `staging`/`production`
promotion behind manual triggers and GitHub environment protection rules. Three gaps in the existing
workflows require remediation: missing CD tag filter, missing CD concurrency group, and `release.yml`
pinned to `@main` instead of a semver tag.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6.2) + Terragrunt 0.56.3 (pinned via `.opentofu-version` / `.terragrunt-version`)
**Primary Dependencies**: `opentofu/setup-opentofu@v1`, `actions/cache@v4`, `jmckenzie17/homeschoolio-shared-actions@v1.3.2` (validate, plan, test, apply, semver-release shared workflows)
**Storage**: Azure Storage Account `homeschooliostfstate` (eastus) — containers `homeschoolio-{env}-infra-tfstate` per Terragrunt root; Azure Blob lease locking
**Testing**: OPA/Conftest (`policies/tags.rego`, `policies/naming.rego`), tfsec, Checkov — all run against plan JSON in the shared `test.yml` workflow; no live cloud environment required
**Target Platform**: GitHub Actions (ubuntu-latest runners); Azure cloud (infra target)
**Project Type**: IaC CI/CD pipeline configuration
**Performance Goals**: CI pipeline completes within 5 minutes of PR event (SC-001); `dev` apply completes within 5 minutes of release event (US3 acceptance scenario 1)
**Constraints**: No external notification channels (GitHub native only); no Infracost; lowest-cost Azure SKUs; shared workflow logic must not be duplicated inline
**Scale/Scope**: 3 environment tiers × 1 domain root (expandable); 1 repo; shared workflows from external pinned repo

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code | PASS | All resources in HCL; no manual changes; secrets via Key Vault data sources (out of scope for this feature but assumed) |
| II. Environment Parity & Promotion | PASS | `dev → staging → production` enforced via `needs:` and `if:` conditions in `cd.yml`; no skip path exists |
| III. Immutable Versioning | **VIOLATION** (justified) | `release.yml` currently pins to `@main` — remediation is a task in this plan (T-fix-release-pin). No other floating refs. |
| IV. Plan Before Apply | PASS | CI generates and publishes plan before any apply; apply jobs in shared `apply.yml` require plan output |
| V. State Isolation & Locking | PASS | Per-environment Blob containers with lease locking; versioning on storage account (assumed by constitution) |
| VI. Cost Consciousness & Observability | PASS | No Infracost; audit logs traceable to commit SHA (FR-013); policy-as-code blocks HIGH/CRITICAL findings |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Constitution III: `release.yml@main` | Existing code pre-dates the spec's pin requirement; must be remediated | Keeping `@main` is a supply-chain risk and constitution violation; fix is a one-line change |

## Project Structure

### Documentation (this feature)

```text
specs/001-terraform-cicd-pipelines/
├── plan.md              ← this file
├── research.md          ← Phase 0 output (existing + updated)
├── data-model.md        ← Phase 1 output (existing)
├── quickstart.md        ← Phase 1 output (existing + updated)
├── contracts/           ← Phase 1 output (workflow interface contracts)
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
.github/
└── workflows/
    ├── ci.yml                    # PR + post-merge CI (validate → plan → test → destructive-op gate)
    ├── cd.yml                    # Release-triggered CD (dev auto; staging/prod manual dispatch)
    └── release.yml               # Semver release (push to main → semantic-release shared workflow)

environments/
├── dev/
│   ├── terragrunt.hcl            # Environment-level locals
│   └── infra/
│       └── terragrunt.hcl        # Domain root: inherits root + env HCL, sources module
├── staging/
│   └── infra/
│       └── terragrunt.hcl
└── production/
    └── infra/
        └── terragrunt.hcl

modules/
└── example/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── version.tf                # locals { module_version = "MAJOR.MINOR.PATCH" }

policies/
├── tags.rego                     # OPA: required tag compliance
└── naming.rego                   # OPA: resource naming convention

terragrunt.hcl                    # Root: remote_state backend generation + common inputs
.opentofu-version                 # Pins OpenTofu 1.6.2
.terragrunt-version               # Pins Terragrunt 0.56.3
```

**Structure Decision**: Single-project IaC layout. No `src/` or `backend/` split — HCL files
ARE the source. The `.github/workflows/` directory contains thin caller workflows; all pipeline
logic lives in shared workflows referenced via `uses:`.

---

## Phase 0: Research Summary

*All NEEDS CLARIFICATION items resolved. See [research.md](research.md) for full findings.*

| Unknown | Resolution |
|---------|------------|
| CD tag filter mechanism | `if:` condition on jobs: `startsWith(github.ref_name, 'v') && !contains(github.ref_name, '-') && github.event.release.prerelease == false` |
| Concurrency group key for CD | Static key `cd-deployment`; `cancel-in-progress: false`; GitHub enforces max 1 pending run |
| `release.yml@main` risk | Supply-chain risk + constitution III violation; pin to `@v1.3.2` |
| Draft vs. published filter | `on.release: published` + `github.event.release.prerelease == false`; `semantic-release` creates non-draft by default |
| CD scope on release | Apply all environment roots unconditionally (no changed-files filtering) |
| Supersession behavior | New release overwrites `dev`; no expiry or gate blocking subsequent runs |

---

## Phase 1: Design & Contracts

### Workflow Interface Contracts

Three caller workflows in `.github/workflows/` — each is a thin shell that passes inputs/secrets
to shared workflows. Contracts are defined in [contracts/](contracts/).

#### `ci.yml` — Trigger contract

```
Trigger:
  - pull_request: [opened, synchronize, reopened] → branches: [main]
  - push: branches: [main]

Concurrency: ci-${{ github.ref }}, cancel-in-progress: true

Jobs (in dependency order):
  validate  → shared: validate.yml@v1.3.2
  plan      → needs: [validate]; shared: plan.yml@v1.3.2; inputs: environments="dev,staging,production"
  test      → needs: [validate, plan]; shared: test.yml@v1.3.2; inputs: plan-json-artifact
  destructive-op-gate → needs: [plan]; inline job (no shared workflow)
    condition: plan.outputs.has-destructive-ops == 'true' && event == pull_request
    action: actions/github-script@v8 — checks PR body for acknowledgment checkbox
```

#### `cd.yml` — Trigger contract (including all clarification fixes)

```
Trigger:
  - release: [published]
  - workflow_dispatch: inputs: target-environment (choice: staging | production)

Concurrency: cd-deployment, cancel-in-progress: false   ← NEW (FR-007a)

Jobs:
  dev-apply
    condition: github.event_name == 'release'
              && startsWith(github.ref_name, 'v')
              && !contains(github.ref_name, '-')
              && github.event.release.prerelease == false    ← NEW (FR-007)
    shared: apply.yml@v1.3.2; with: target-environment=dev

  staging-apply
    needs: [dev-apply]; condition: manual dispatch for staging OR dev-apply succeeded
    shared: apply.yml@v1.3.2; with: target-environment=staging

  production-apply
    needs: [staging-apply]; condition: manual dispatch for production AND staging succeeded
    shared: apply.yml@v1.3.2; with: target-environment=production
```

#### `release.yml` — Trigger contract (remediation)

```
Trigger: push: branches: [main]

Jobs:
  semver-release
    shared: semver-release.yml@v1.3.2   ← FIX: was @main (FR-011, constitution III)
    inputs: release-branch=main, tag-prefix="v"
    secrets: inherit
```

### Data Model

See [data-model.md](data-model.md) — no changes required from Phase 0 clarifications.

### Key Design Decisions

1. **Tag filter `if:` condition placement**: Applied to the `dev-apply` job (the only release-triggered
   job). `staging-apply` and `production-apply` use `workflow_dispatch` and are never triggered directly
   by a release event, so they do not need the same filter.

2. **`github.event.release.prerelease` vs. tag `-` check**: Use both. `startsWith(github.ref_name, 'v') && !contains(github.ref_name, '-')` handles the tag pattern; `github.event.release.prerelease == false` handles the GitHub release metadata. Belt-and-suspenders approach costs nothing.

3. **Concurrency group is static `cd-deployment`**: A release always has a unique `github.ref`
   (e.g., `refs/tags/v1.2.3`), so using `${{ github.ref }}` as the group key would allow
   unlimited concurrent deployments. A static key ensures only one CD run is active at a time.

4. **All roots applied unconditionally**: The CD apply.yml shared workflow runs `terragrunt run-all apply`
   across all environment roots. No changed-files filtering in CD — every release represents full desired
   state. No-op roots (no diff) complete quickly and do not block the run.

5. **`release.yml` pin fix**: One-line change from `@main` to `@v1.3.2`. No functional change; pure
   supply-chain and constitution compliance fix.

---

## Agent Context Update

Run after Phase 1 artifacts are complete:

```bash
.specify/scripts/bash/update-agent-context.sh claude
```

New technology to add to agent context:
- GitHub Actions `on.release: published` event with job-level `if:` tag filter
- GitHub Actions `concurrency:` with static group key and `cancel-in-progress: false`
- `semantic-release` via `jmckenzie17/homeschoolio-shared-actions/semver-release.yml`

---

## Post-Phase 1 Constitution Check

All gates pass after design decisions above:
- Principle III violation (release.yml@main) has a concrete remediation task (not deferred)
- No new floating refs introduced
- CD concurrency design eliminates parallel-apply risk (Principle V: state locking)
- All apply jobs gated behind plan (Principle IV)
- Environment promotion order enforced (Principle II)

---

## Artifacts Generated

| File | Status |
|------|--------|
| `research.md` | Updated with new decisions (CD trigger filter, concurrency, pin fix) |
| `data-model.md` | Existing — no changes required |
| `quickstart.md` | Updated — removed stale `@main` note; added CD trigger filter validation step |
| `contracts/` | New — workflow interface contracts (ci.yml, cd.yml, release.yml) |
| `plan.md` | This file |
