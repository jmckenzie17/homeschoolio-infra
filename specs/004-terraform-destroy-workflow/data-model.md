# Data Model: Terraform Infrastructure Destroy Workflow

This workflow is a GitHub Actions YAML file, not a data-driven application. There are no persistent entities, databases, or schemas. This document captures the logical entities that flow through the workflow.

## Workflow Inputs

| Input Name | Type | Required | Values | Description |
|---|---|---|---|---|
| `environment` | choice | Yes | `dev`, `staging`, `production` | Target environment to destroy |
| `confirm_destroy` | boolean | Yes | `true` / `false` | Explicit confirmation; workflow aborts if `false` |

## Destroy Target

A **Destroy Target** is the combination of environment + ordered list of Terragrunt roots.

| Field | Value |
|---|---|
| Environment | Selected via `workflow_dispatch` input |
| Roots (in destroy order) | `postgresql`, `key-vault`, `aks`, `resource-group` |
| State backend | `homeschooliostfstate` / `homeschoolio-{env}-infra-tfstate` |
| Working directories | `environments/{env}/{root}/` |

## Destroy Run Result

Each root produces a result captured in the job step summary.

| Field | Description |
|---|---|
| Root name | e.g., `postgresql` |
| Status | `success` or `failure` |
| Actor | `github.actor` — the user who triggered the workflow |
| Environment | Selected environment |
| Triggered at | `github.event.created_at` (workflow run timestamp) |
| Run URL | Link to the GitHub Actions run for audit trail |

## Destroy Order (Dependency Reverse)

```
postgresql    ← depends on aks (outbound IP), resource-group
key-vault     ← depends on aks (workload identity), resource-group
aks           ← depends on resource-group
resource-group ← root; destroyed last
```

Destroy order: `postgresql → key-vault → aks → resource-group`
