# Contract: CD Workflow Inputs/Outputs

**Workflow file**: `.github/workflows/cd.yml` (caller, in this repo)
**Triggered by**: `release: published` with tag matching `v[0-9]+.[0-9]+.[0-9]+` (non-draft, non-prerelease) → auto-applies to `dev`; `workflow_dispatch` (staging/prod manual promotion)

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

## Concurrency

```yaml
concurrency:
  group: cd-deployment
  cancel-in-progress: false
```

One active CD run at a time. A second release published while one run is active is queued
(GitHub limit: 1 pending per group). A third release supersedes the pending run.

## Tag Filter (applied to `dev-apply` job)

```yaml
if: |
  github.event_name == 'release' &&
  startsWith(github.ref_name, 'v') &&
  !contains(github.ref_name, '-') &&
  github.event.release.prerelease == false
```

Pre-release tags (e.g., `v2.0.0-beta.1`) and draft releases MUST NOT trigger `dev-apply`.

## GitHub Environment Mapping

| Job | GitHub Environment | Protection Rules |
|-----|-------------------|-----------------|
| `dev-apply` | `dev` | None; triggers automatically on stable release event |
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
