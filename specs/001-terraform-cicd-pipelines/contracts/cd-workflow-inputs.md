# Contract: CD Workflow Inputs/Outputs

**Workflow file**: `.github/workflows/cd.yml` (caller, in this repo)
**Triggered by**: `push` to `main` (auto-apply dev); `workflow_dispatch` (staging/prod)

## Inputs (passed to shared workflows)

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `target-environment` | string | Yes | — | One of: `dev`, `staging`, `production` |
| `opentofu-version` | string | No | `1.6.x` | OpenTofu CLI version |
| `terragrunt-version` | string | No | `0.56.x` | Terragrunt CLI version |
| `auto-approve` | boolean | No | `false` | Skip interactive approval (only valid for dev) |

## Secrets (passed to shared workflows)

| Secret | Scope | Description |
|--------|-------|-------------|
| `dev-azure-credentials` | dev environment | Azure OIDC/service principal credentials for dev apply |
| `staging-azure-credentials` | staging environment | Azure OIDC/service principal credentials for staging apply |
| `production-azure-credentials` | production environment | Azure OIDC/service principal credentials for production apply |
| `github-token` | all | For artifact download and status reporting |

## GitHub Environment Mapping

| Job | GitHub Environment | Protection Rules |
|-----|-------------------|-----------------|
| `dev-apply` | `dev` | None; triggers automatically on merge |
| `staging-apply` | `staging` | None; triggered manually via `workflow_dispatch` |
| `production-apply` | `production` | Required reviewers (1+ designated approvers) |

## Promotion Chain Constraints

- `staging-apply` MUST declare `needs: dev-apply`; will not run if dev failed
- `production-apply` MUST declare `needs: staging-apply`; will not run if staging failed
- Each apply job MUST run a pre-apply plan and confirm plan is non-empty before applying
- Any apply failure MUST cause the job to exit non-zero, halting the chain

## Outputs

| Output | Description |
|--------|-------------|
| `dev-apply-sha` | Commit SHA successfully applied to dev |
| `staging-apply-sha` | Commit SHA successfully applied to staging |
| `production-apply-sha` | Commit SHA successfully applied to production |
