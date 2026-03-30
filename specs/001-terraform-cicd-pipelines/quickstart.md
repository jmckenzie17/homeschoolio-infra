# Quickstart: OpenTofu/Terragrunt CI/CD Pipelines

**Feature**: 001-terraform-cicd-pipelines
**Date**: 2026-03-30 (updated for dev-only scope)

> **Scope note**: This feature deploys to the `dev` environment only. Staging and
> production promotion are out of scope and will be addressed in a future feature.

## Prerequisites

Before implementing, verify:

- [ ] Repository has `environments/dev/infra/` directory structure
- [ ] At least one module exists under `modules/` (currently `modules/example`)
- [ ] Remote state backend is configured per project constitution (Azure Storage Account + Blob lease locking; `homeschoolio-dev-infra-tfstate` container)
- [ ] `jmckenzie17/homeschoolio-shared-actions` is at tag `v1.3.6` with all shared workflows
- [ ] GitHub repository admin access (to configure branch protection)

---

## Step 1: Configure GitHub Branch Protection

In GitHub → Repository → Settings → Branches → Add rule for `main`:

1. Check **Require a pull request before merging**
   - Set **Required approvals**: 1
2. Check **Require status checks to pass before merging**
   - Add required checks: `Validate`, `Plan`, `Test`, `Destructive Operation Gate`
   - Note: `Destructive Operation Gate` only runs when the plan contains destructive ops; GitHub will treat it as optional when it doesn't trigger.
   - Check **Require branches to be up to date before merging**
3. Click **Save changes**

**Validation**: Open a PR and confirm the merge button is blocked until `Validate`, `Plan`, and
`Test` checks all pass.

---

## Step 2: Configure GitHub Environments

In GitHub → Repository → Settings → Environments:

1. Create `dev` — no protection rules required for this feature

Staging and production environments are out of scope for this feature.

---

## Step 3: Add Azure OIDC Secrets

For each GitHub environment, add the following secrets (use OIDC workload identity federation):

Each environment uses the same secret names (scoped per environment, so no prefix needed):
- `AZURE_CLIENT_ID` — Managed Identity / App Registration client ID
- `AZURE_TENANT_ID` — Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` — Azure subscription ID

To configure OIDC federation for each managed identity, add the following federated credential:
- Issuer: `https://token.actions.githubusercontent.com`
- Subject: `repo:{owner}/{repo}:environment:{environment-name}`
- Audience: `api://AzureADTokenExchange`

---

## US1 Validation: CI Pipeline on PRs

1. Create a feature branch with a trivial `.hcl` whitespace change
2. Open a PR targeting `main`
3. Verify CI triggers automatically within 2 minutes
4. Confirm three check stages appear in the PR checks panel: **validate**, **test**, **plan**
5. Confirm the merge button is blocked until all three pass
6. To test the destructive-op gate: add a resource delete to the plan, verify the plan check
   sets `has-destructive-ops = true` and blocks merge until the PR description includes:
   ```
   - [x] I acknowledge destructive operations in this plan
   ```

---

## US2 Validation: CI Detects Test Failures

1. Create a branch adding an Azure resource missing the `Owner` tag:
   ```hcl
   resource "azurerm_resource_group" "example" {
     name     = "homeschoolio-dev-rg-example"
     location = "eastus"
     tags = {
       Project     = "homeschoolio"
       Environment = "dev"
       ManagedBy   = "opentofu"
       # Owner tag deliberately omitted
     }
   }
   ```
2. Open a PR and let CI run
3. Verify the **test** check fails
4. Verify the failure annotation identifies the specific resource address and missing tag:
   ```
   Resource azurerm_resource_group.example (azurerm_resource_group) is missing required tag: Owner
   ```
5. Add the missing tag, push to the branch, verify **test** passes

---

## US3 Validation: Merge to Main Deploys to Dev

1. Merge a PR with a qualifying conventional commit (e.g., `feat:` or `fix:`)
2. Verify the **CD** workflow runs on push to `main`
3. Verify the **release** job creates a GitHub release with a stable semver tag (e.g., `v1.1.0`)
4. Verify the **Apply to dev** job triggers automatically (gates on `release-created == 'true'`) within 5 minutes
5. Verify no staging or production jobs appear in the workflow run

If the apply fails, verify the pipeline stops with a clear error visible in GitHub Actions.

---

## US4 Validation: Semver Release via Conventional Commits

The `release` job in `cd.yml` runs `semantic-release` on every push to `main`. The
`dev-apply` job only runs when `release-created == 'true'`.

1. Merge a PR whose commits include `feat: add vpc module`
   - Verify Git tag `v{NEXT_MINOR}` (e.g., `v1.1.0`) is created within 2 minutes
   - Verify the floating `v1` pointer tag is updated
   - Verify the `dev-apply` job runs automatically after `release`

2. Merge a PR whose commits include `fix: correct subnet CIDR`
   - Verify Git tag `v{NEXT_PATCH}` (e.g., `v1.0.1`) is created
   - Verify `dev-apply` runs

3. Merge a PR containing `BREAKING CHANGE` in a commit footer
   - Verify Git tag `v{NEXT_MAJOR}` (e.g., `v2.0.0`) is created

4. Merge a PR whose commits are only `chore:` or `docs:` type
   - Verify **no new tag** is created
   - Verify `dev-apply` is **skipped** (condition `release-created == 'true'` is false)

To reference a tag in a downstream `terragrunt.hcl`:
```hcl
terraform {
  source = "git::https://github.com/jmckenzie17/homeschoolio-infra.git//modules/example?ref=v1.1.0"
}
```

---

## US5 Validation: Shared Workflow Upgrade Process

To upgrade the pinned shared workflow version:

1. Check [jmckenzie17/homeschoolio-shared-actions releases](https://github.com/jmckenzie17/homeschoolio-shared-actions/releases) for new tags
2. Open a PR in this repo updating the version in each `uses:` line in `.github/workflows/ci.yml` and `cd.yml`.
   GitHub Actions does not allow env vars in `uses:` fields, so the version must be a literal string.
   Update all occurrences (validate, test, plan in ci.yml; three apply calls in cd.yml):
   ```yaml
   uses: jmckenzie17/homeschoolio-shared-actions/.github/workflows/validate.yml@v1.3.0
   ```
   The comment at the top of each workflow file shows the current pinned version.
3. Verify CI passes with the new shared workflow version
4. Merge — new behavior takes effect with no other changes to this repo

---

## Upgrading Shared Workflow Versions

No workflow logic needs to be copied or re-implemented locally. To upgrade, open a PR bumping the
pinned version literal in every `uses:` line in `ci.yml` and `cd.yml` (e.g., `@v1.3.6` → `@v1.4.0`).
GitHub Actions does not support env vars in `uses:` fields; the version must be a literal string.
The comment at the top of each workflow file (`# Current pinned version: vX.Y.Z`) tracks the
current version — update this comment in the same PR.
