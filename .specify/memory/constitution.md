<!--
Sync Impact Report
==================
Version change: 1.0.2 → 1.1.0
Modified principles:
  - VI. Observability & Auditability: removed Infracost mandate; replaced with
    lowest-cost tier selection policy and POC-appropriate SLA posture
Modified sections:
  - Deployment Workflow: removed "Cost delta reviewed" PR gate item
  - Principle V rationale: removed "enterprise operations" framing
  - Principle VI rationale: updated to POC context
Added sections: none
Removed sections: none
Templates requiring updates:
  ✅ .specify/memory/constitution.md — written (this file)
  ✅ .specify/templates/plan-template.md — no structural change required
  ✅ .specify/templates/spec-template.md — no structural change required
  ✅ .specify/templates/tasks-template.md — no structural change required
  ✅ CLAUDE.md — auto-generated; no constitution-specific content to update
Deferred TODOs: none
-->

# homeschoolio-infra Constitution

## Core Principles

### I. Infrastructure as Code (NON-NEGOTIABLE)

All infrastructure resources MUST be defined in OpenTofu HCL and managed through
Terragrunt. Manual changes to cloud resources are strictly prohibited; any drift
detected MUST be remediated by updating the IaC source, never by hand-editing the
provider directly.

- Every resource MUST have a corresponding `.tf` file under the appropriate module.
- Terragrunt DRY wrappers MUST be used to compose modules across environments;
  copy-pasted `provider` or `backend` blocks are forbidden.
- Secrets MUST NOT be stored in source files; use Azure Key Vault referenced via
  data sources.

**Rationale**: Manual changes create untracked drift, audit failures, and
unrepeatability—unacceptable in an automated CD pipeline.

### II. Environment Parity & Promotion

Infrastructure changes MUST follow a strict environment promotion path:
`dev → staging → production`. No change may skip an environment tier.

- Each environment MUST be a separate Terragrunt root with its own state backend.
- `production` applies MUST be gated by a passing `staging` plan and apply.
- Environment-specific variable files MUST be the only source of divergence between
  tiers; module code MUST be identical across environments.

**Rationale**: Prevents "works in dev" failures from reaching production and ensures
every change is validated before it carries real-world impact.

### III. Immutable Versioning

All OpenTofu modules MUST be versioned using semantic versioning (`MAJOR.MINOR.PATCH`).
External module sources MUST pin to an explicit version tag; floating references
(e.g., `?ref=main`) are forbidden in non-development branches.

- MAJOR: backward-incompatible interface changes (variable removals/renames, output
  removals).
- MINOR: backward-compatible additions (new optional variables, new outputs).
- PATCH: bug fixes and non-semantic refinements with no interface change.
- A `CHANGELOG.md` entry MUST accompany every module version bump.

**Rationale**: Unpinned references make infrastructure non-reproducible and can
silently introduce breaking upstream changes into production pipelines.

### IV. Plan Before Apply (NON-NEGOTIABLE)

Every infrastructure change MUST be preceded by a reviewed `terragrunt plan` output.
Applies without a reviewed plan are forbidden in staging and production environments.

- CI MUST generate and publish the plan as an artifact on every PR.
- Plan output MUST be reviewed and approved by at least one engineer who did not
  author the change before an apply is permitted.
- Destructive operations (resource deletions, replacements) MUST be explicitly
  acknowledged in the PR description.

**Rationale**: Unreviewed applies are the single largest source of production
infrastructure incidents; the plan review is the last safety gate before irreversible
change.

### V. State Isolation & Locking

OpenTofu state MUST be stored remotely in an Azure Storage Account (Blob container)
with Azure Blob lease-based locking. Local state is prohibited outside of ephemeral
sandbox environments.

- Each storage account container MUST correspond to exactly one Terragrunt root
  (one environment tier + one logical domain) to minimize blast radius.
- State locking MUST be enabled via Azure Blob lease; concurrent applies to the same
  state are forbidden.
- The storage account MUST have versioning enabled so prior state versions are
  recoverable.
- State files MUST never be committed to version control.
- The storage account and container MUST be tagged and access-controlled independently
  from the resources they track.

**Rationale**: Shared or local state leads to concurrent-write corruption, accidental
exposure of sensitive resource metadata, and unrecoverable state loss. Blob versioning
provides a recovery safety net without requiring additional tooling.

### VI. Cost Consciousness & Observability

This is a proof-of-concept project. Resource selection MUST favour the lowest-cost
tier that satisfies functional requirements. Enterprise-grade SLAs and high-availability
configurations are explicitly out of scope unless a specific requirement demands them.

- All infrastructure deployments MUST emit audit logs traceable to a commit SHA and PR.
- Policy-as-code checks (OPA, Checkov, tfsec) MUST run in CI and block merges on
  HIGH-severity findings.
- Azure resource SKUs MUST default to the lowest available pricing tier (e.g., `Free`,
  `Basic`, or `Standard` tiers) unless a functional constraint requires otherwise;
  the constraint MUST be documented in the relevant module or environment config.
- Automated cost estimation tools (e.g., Infracost) are NOT required; cost awareness
  is achieved through deliberate tier selection at authoring time.

**Rationale**: As a POC, the priority is learning and iteration speed over resilience
and cost optimisation tooling. Lowest-tier defaults keep cloud spend predictable without
requiring additional CI integrations.

## Infrastructure Standards

- **Cloud provider**: All infrastructure resources MUST be hosted on Microsoft Azure.
  No other cloud provider may be used without a constitution amendment.
- **OpenTofu version**: Pin via `.opentofu-version` or `required_version` constraint;
  all engineers and CI MUST use the same version.
- **Terragrunt version**: Pin via `.terragrunt-version`; bumps require a PR and
  validation across all root configurations.
- **Provider versions**: The AzureRM provider MUST use `~>` pessimistic constraint
  operators locked to the minor version (e.g., `~> 3.0`).
- **State backend**: Azure Storage Account + Blob container per Terragrunt root;
  container name format: `{project}-{environment}-{domain}-tfstate`.
- **Naming conventions**: Resources MUST follow `{project}-{environment}-{resource-type}-{descriptor}`
  (e.g., `homeschoolio-prod-nsg-web`).
- **Tagging**: Every taggable resource MUST carry at minimum: `Project`, `Environment`,
  `ManagedBy = "opentofu"`, and `Owner`.
- **Module structure**: Reusable modules MUST live under `modules/`; environment
  compositions MUST live under `environments/{env}/`.
- **Resource tiers**: Default to the lowest-cost SKU that satisfies the functional
  requirement; document any deviation in the module or environment config.

## Deployment Workflow

- **Branching**: Feature branches off `main`; branch name format `###-short-description`.
- **PR gates (all MUST pass before merge)**:
  1. `terragrunt validate` across all changed roots.
  2. `terragrunt plan` artifact published and reviewed.
  3. Policy-as-code scan with zero HIGH/CRITICAL findings.
  4. At least one peer review approval.
- **Merge to `main`**: Triggers the release workflow; qualifying conventional commits
  create a GitHub release which in turn triggers the CD pipeline.
- **Promotion to `staging`**: Manual trigger after `dev` apply succeeds; requires
  plan review.
- **Promotion to `production`**: Manual trigger after `staging` apply succeeds;
  requires plan review + GitHub environment protection gate (required reviewer approval).
- **Rollback**: MUST be performed via revert commit + re-apply, never via
  `tofu state` surgery without explicit runbook approval.

## Governance

This constitution supersedes all other documented practices for this repository.
Amendments MUST follow this procedure:

1. Open a PR with the proposed change to `.specify/memory/constitution.md`.
2. Describe the motivation, the principle affected, and the version bump type.
3. Obtain approval from at least one other maintainer.
4. Update all dependent templates and documentation in the same PR.
5. Merge with a commit message of the form:
   `docs: amend constitution to vX.Y.Z (<brief reason>)`

**Versioning policy**:
- MAJOR: removal or redefinition of a non-negotiable principle.
- MINOR: new principle or materially expanded guidance added.
- PATCH: clarifications, wording fixes, non-semantic refinements.

**Compliance review**: All PRs MUST verify compliance against this constitution at
the "Constitution Check" gate in the implementation plan. Complexity violations MUST
be justified in the plan's Complexity Tracking table.

**Version**: 1.1.0 | **Ratified**: 2026-03-26 | **Last Amended**: 2026-03-27
