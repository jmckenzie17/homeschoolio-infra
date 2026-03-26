# Data Model: OpenTofu/Terragrunt CI/CD Pipelines

**Feature**: 001-terraform-cicd-pipelines
**Date**: 2026-03-26

## Entities

### Pipeline Run

Represents a single execution of the CI or CD pipeline.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `run_id` | string | GitHub Actions run ID | Unique; provided by GitHub |
| `trigger_sha` | string | Git commit SHA that triggered the run | 40-char hex; required |
| `trigger_pr` | integer | PR number (null for post-merge runs) | Optional |
| `branch` | string | Branch name at trigger time | Required |
| `pipeline_type` | enum | `ci` or `cd` | Required |
| `status` | enum | `pending`, `running`, `success`, `failure`, `cancelled` | Required |
| `started_at` | timestamp | ISO 8601 UTC | Required |
| `completed_at` | timestamp | ISO 8601 UTC | Null while running |

**Lifecycle**: `pending` → `running` → `success` | `failure` | `cancelled`

---

### Environment Root

A Terragrunt configuration directory representing one environment tier for one
infrastructure domain.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `path` | string | Relative path from repo root | e.g., `environments/dev/networking` |
| `environment` | enum | `dev`, `staging`, `production` | Required |
| `domain` | string | Infrastructure domain name | e.g., `networking`, `compute`, `data` |
| `state_backend` | string | Azure Storage Account container URI | Required; unique per root; format: `{account}/{container}` |
| `last_applied_sha` | string | Commit SHA of last successful apply | Updated on apply |
| `last_plan_sha` | string | Commit SHA of last generated plan | Updated on plan |

**Relationships**: One environment root produces zero or one Plan Artifact per pipeline run.

---

### Module Version

A versioned OpenTofu module with an associated Git release tag.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `module_name` | string | Module directory name under `modules/` | e.g., `vpc`, `ecs-cluster` |
| `version` | string | `MAJOR.MINOR.PATCH` semver string | Must match `^[0-9]+\.[0-9]+\.[0-9]+$` |
| `git_tag` | string | Git tag created on release | Format: `modules/{name}/{version}` |
| `tagged_sha` | string | Commit SHA the tag points to | 40-char hex |
| `version_file_path` | string | Path to `version.tf` | `modules/{name}/version.tf` |
| `bump_type` | enum | `major`, `minor`, `patch` | Determined at tag time |

**Validation rule**: A PATCH bump that modifies variable declarations MUST generate a
CI warning. A MAJOR bump that does not modify variable declarations SHOULD generate a
CI warning.

**Version source**:
```hcl
# modules/{name}/version.tf
locals {
  module_version = "1.2.3"
}
```

---

### Plan Artifact

The output of a `terragrunt plan` execution for a specific environment root.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `artifact_id` | string | GitHub Actions artifact ID | Unique per run |
| `environment_root` | string | Path of the environment root | FK → Environment Root |
| `pipeline_run_id` | string | Parent pipeline run | FK → Pipeline Run |
| `plan_json_path` | string | Path to `tfplan.json` within artifact | Required |
| `has_destructive_ops` | boolean | True if plan contains resource deletions or replacements | Required |
| `resource_add_count` | integer | Count of resources to add | ≥ 0 |
| `resource_change_count` | integer | Count of resources to change | ≥ 0 |
| `resource_destroy_count` | integer | Count of resources to destroy | ≥ 0 |
| `acknowledged` | boolean | Author acknowledged destructive ops | Required when `has_destructive_ops` is true |

**Lifecycle**: Created during CI plan stage; linked to PR as comment; reviewed before
merge gate clears.

---

### Shared Workflow Reference

A pinned reference from this repo to a reusable workflow in `homeschoolio-shared-workflows`.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `workflow_name` | string | Logical name (validate, test, plan, apply, tag) | Required |
| `source_repo` | string | `homeschoolio/homeschoolio-shared-workflows` | Fixed |
| `workflow_file` | string | Path within source repo | e.g., `.github/workflows/validate.yml` |
| `pinned_version` | string | Semver tag | Must match `^v[0-9]+\.[0-9]+\.[0-9]+$` |
| `caller_workflow` | string | Which local workflow uses this | e.g., `ci.yml`, `cd.yml` |

**Constraint**: `pinned_version` MUST be an exact semver tag. Floating references
(`@main`, `@v1`) are forbidden per constitution Principle III.

---

## State Transitions

### CD Environment Promotion

```text
[PR Merged to main]
       │
       ▼
  dev-apply ──(fail)──► STOP (no staging)
       │
    (success)
       │
       ▼
  staging-apply ◄── manual trigger
  (no protection)
       │
    (success)
       │
       ▼
  production-apply ◄── manual trigger + required reviewer approval
  (GitHub env gate)
       │
    (success)
       │
       ▼
   [Complete]
```

### Module Version Tag Lifecycle

```text
[PR with version.tf bump merged]
       │
       ▼
  Detect changed modules (git diff)
       │
       ▼
  Validate semver format
       │
       ▼
  Create tag: modules/{name}/{version}
  pointing to merge SHA
       │
       ▼
  Tag available for downstream pin
```
