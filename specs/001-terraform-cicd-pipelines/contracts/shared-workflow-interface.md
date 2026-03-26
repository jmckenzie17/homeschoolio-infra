# Contract: Shared Workflow Interface

**Shared repo**: `homeschoolio/homeschoolio-shared-workflows`
**Pinning policy**: All `uses:` references MUST pin to an exact semver tag
  (e.g., `@v1.2.0`). Floating refs (`@main`, `@v1`) are forbidden.

## Workflows Consumed by This Repo

### validate.yml

**Purpose**: Run `tofu validate` + `terragrunt fmt --check` across all changed roots.

**Trigger**: `workflow_call`

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `opentofu-version` | string | No | Version to install |
| `terragrunt-version` | string | No | Version to install |
| `working-directory` | string | No | Repo root; defaults to `.` |

| Secret | Required | Description |
|--------|----------|-------------|
| `backend-credentials` | Conditional | Only if `init` requires auth |

| Output | Description |
|--------|-------------|
| `validation-passed` | Boolean string `true`/`false` |

---

### test.yml

**Purpose**: Run tfsec (static HCL) + Checkov (plan JSON) + Conftest (custom policies).

**Trigger**: `workflow_call`

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `plan-json-artifact` | string | Yes | Name of artifact containing `tfplan.json` |
| `tfsec-minimum-severity` | string | No | Default: `HIGH` |
| `checkov-framework` | string | No | Default: `terraform_plan` |
| `policy-path` | string | No | Path to OPA policies; default: `policies/` |

| Output | Description |
|--------|-------------|
| `tests-passed` | Boolean string |
| `sarif-artifact` | Artifact name containing merged SARIF for GitHub upload |

---

### plan.yml

**Purpose**: Generate `terragrunt plan` for all changed environment roots; publish as
PR comment and artifact.

**Trigger**: `workflow_call`

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `environments` | string | No | Comma-separated env names; default: `dev,staging,production` |
| `opentofu-version` | string | No | Version to install |

| Output | Description |
|--------|-------------|
| `affected-roots` | Comma-separated paths of changed roots |
| `has-destructive-ops` | Boolean string; `true` if any destroy/replace in plan |
| `plan-artifact` | Artifact name containing plan JSON files per root |

---

### apply.yml

**Purpose**: Run `terragrunt run-all apply` for a specified environment.

**Trigger**: `workflow_call`

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `target-environment` | string | Yes | `dev`, `staging`, or `production` |
| `opentofu-version` | string | No | Version to install |

| Secret | Required | Description |
|--------|----------|-------------|
| `aws-role-arn` | Yes | IAM role ARN for the target environment |

| Output | Description |
|--------|-------------|
| `applied-sha` | Commit SHA successfully applied |

---

### tag.yml

**Purpose**: Detect module version bumps and create Git tags on merge.

**Trigger**: `workflow_call`

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `base-ref` | string | No | Default: `main` |
| `tag-prefix` | string | No | Default: `modules/` |

| Secret | Required | Description |
|--------|----------|-------------|
| `github-token` | Yes | For creating Git tags |

| Output | Description |
|--------|-------------|
| `tags-created` | Newline-separated list of created tags; empty if no bumps |

---

## Versioning Policy for This Interface

| Bump Type | When to Apply |
|-----------|--------------|
| PATCH | Bug fix in a workflow step; no input/output/behavior change |
| MINOR | New optional input added; new output added; new workflow file added |
| MAJOR | Required input added; existing input/output renamed or removed; behavior change that breaks callers |

This repo MUST update its pinned tag reference when upgrading. The upgrade PR MUST
describe the shared workflow changelog entries being adopted.
