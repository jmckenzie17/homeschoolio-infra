# Implementation Plan: Azure Temporal Self-Hosted Infrastructure

**Branch**: `003-azure-temporal-infra` | **Date**: 2026-03-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-azure-temporal-infra/spec.md`

## Summary

Provision the Azure infrastructure required to self-host Temporal on AKS, using three reusable
OpenTofu modules (`azure-aks`, `azure-postgresql`, `azure-key-vault`) composed per environment
via Terragrunt. The AKS API server and PostgreSQL use public endpoints restricted by IP allowlists;
Key Vault uses a public endpoint with RBAC-only access control. No VNet, private endpoints, or VPN
Gateway are provisioned.

## Technical Context

**Language/Version**: HCL (OpenTofu 1.6.2, pinned via `.opentofu-version`)
**Primary Dependencies**: AzureRM provider `~> 3.0` (≥ 3.27 required for `public_network_access_enabled`); Terragrunt 0.56.3
**Storage**: Azure Blob Storage (`homeschooliostfstate`) — remote state only; PostgreSQL Flexible Server — Temporal workflow state
**Testing**: `terragrunt validate` + `terragrunt plan` (zero-change idempotency); Conftest OPA policy checks; tfsec; Checkov
**Target Platform**: Azure (eastus); Kubernetes (AKS 1.28+)
**Project Type**: Infrastructure-as-code (IaC provisioning only — no application deployment)
**Performance Goals**: N/A for provisioning; database SKU sized for Temporal (max_connections = 300)
**Constraints**: POC — lowest-cost SKUs per constitution Principle VI; public endpoints acceptable; dev node count = 1
**Scale/Scope**: 3 environments (dev, staging, production); 3 reusable modules; ~6 Terragrunt roots total

## Constitution Check

*GATE: Must pass before implementation. Re-checked after design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code | PASS | All resources in HCL modules; no manual changes |
| II. Environment Parity & Promotion | PASS | dev → staging → production via identical module code; env-specific values in Terragrunt inputs only |
| III. Immutable Versioning | PASS | AzureRM pinned `~> 3.0`; OpenTofu/Terragrunt pinned via version files; `version.tf` carries `module_version` local |
| IV. Plan Before Apply | PASS | CI generates plan artifact per PR; PR gate enforced by shared workflow |
| V. State Isolation & Locking | PASS | One state key per Terragrunt root in existing `homeschooliostfstate` account; Azure Blob lease locking |
| VI. Cost Consciousness | PASS | `Standard_D2s_v3` AKS node (dev×1); `GP_Standard_D2s_v3` PostgreSQL; Key Vault Standard SKU; no VPN Gateway (removed) |

No violations. Complexity Tracking table not required.

## Project Structure

### Documentation (this feature)

```text
specs/003-azure-temporal-infra/
├── plan.md           # This file
├── research.md       # Phase 0 — provider API decisions, patterns
├── data-model.md     # Phase 1 — resource entity model and dependency graph
└── tasks.md          # Phase 2 output (/speckit.tasks — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
modules/
├── azure-resource-group/   # existing (feature 002)
├── azure-aks/              # this feature — rework: remove VNet inputs, add public cluster config
├── azure-postgresql/       # this feature — rework: remove VNet injection, add public endpoint + firewall
└── azure-key-vault/        # this feature — rework: remove private endpoint, add public RBAC-only config

environments/
├── dev/
│   ├── terragrunt.hcl       # existing env-level root
│   ├── resource-group/      # existing
│   ├── aks/                 # this feature — update inputs: remove vnet dependency
│   ├── postgresql/          # this feature — update inputs: remove vnet dependency, add firewall IP
│   └── key-vault/           # this feature — update inputs: remove vnet dependency
├── staging/
│   ├── aks/                 # this feature
│   ├── postgresql/          # this feature
│   └── key-vault/           # this feature
└── production/
    ├── aks/                 # this feature
    ├── postgresql/          # this feature
    └── key-vault/           # this feature

policies/
└── naming.rego              # update: add new resource types to enforced_types set
```

**Structure Decision**: Three-module IaC layout matching the existing `modules/` + `environments/` pattern from features 001–002. No VNet or VPN Gateway modules. AKS and PostgreSQL use public endpoints; Key Vault is public with RBAC. Each environment root has independent Terragrunt state.

## Complexity Tracking

No constitution violations — table not required.
