# Quickstart: OpenTofu/Terragrunt CI/CD Pipelines

**Feature**: 001-terraform-cicd-pipelines
**Date**: 2026-03-26

## Prerequisites

Before implementing, verify:

- [ ] Repository has `environments/dev/`, `environments/staging/`, `environments/production/` directory structure
- [ ] At least one module exists under `modules/`
- [ ] Remote state backend is configured per project constitution (Azure Storage Account + Blob lease locking)
- [ ] `jmckenzie17/homeschoolio-shared-actions` repository is at tag `v1.0.0` with all shared workflows
- [ ] GitHub repository admin access (to configure environments and branch protection)

---

## Step 1: Configure GitHub Branch Protection (T017)

In GitHub → Repository → Settings → Branches → Add rule for `main`:

1. Check **Require a pull request before merging**
   - Set **Required approvals**: 1
2. Check **Require status checks to pass before merging**
   - Add required checks: `validate`, `test`, `plan`
   - Check **Require branches to be up to date before merging**
3. Click **Save changes**

**Validation**: Open a PR and confirm the merge button is blocked until `validate`, `test`, and
`plan` checks all pass.

---

## Step 2: Configure GitHub Environments (T022)

In GitHub → Repository → Settings → Environments:

1. Create `dev` — no protection rules
2. Create `staging` — no protection rules (manual `workflow_dispatch` is the gate)
3. Create `production`:
   - Add **Required reviewers** (1+ individuals or teams)
   - Set **Deployment branches**: Selected branches → `main`
   - (Optional) Add a **Wait timer** (e.g., 60 minutes for smoke-test window)

---

## Step 3: Add Azure OIDC Secrets per Environment (T023)

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

## US3 Validation: Environment Promotion Chain

1. Merge a PR with a qualifying conventional commit (e.g., `feat:` or `fix:`)
2. Verify the **release** workflow runs and a GitHub release is published with a stable semver tag (e.g., `v1.1.0`)
3. Verify the **Apply to dev** job triggers automatically on the release event within 5 minutes
   - To verify the tag filter works: manually create a GitHub release with a pre-release tag (e.g., `v1.2.0-beta.1`) or mark the release as a pre-release; confirm the CD `dev-apply` job is skipped (condition evaluates false)
5. To trigger staging promotion:
   - Go to Actions → CD workflow → click **Run workflow**
   - Select `target-environment: staging`
   - Verify `staging-apply` job runs after `dev-apply` succeeds
6. To trigger production promotion:
   - Go to Actions → CD workflow → click **Run workflow**
   - Select `target-environment: production`
   - Verify the pipeline pauses at the `production` environment protection gate (enforced inside `apply.yml`)
   - Approve the deployment via the Actions UI
   - Verify `production-apply` runs only after approval

If any apply fails, verify the pipeline stops with a clear error and no further promotion occurs.

---

## US4 Validation: Semver Release via Conventional Commits

1. Merge a PR whose commits include `feat: add vpc module`
   - Verify Git tag `v{NEXT_MINOR}` (e.g., `v1.1.0`) is created within 2 minutes
   - Verify the floating `v1` pointer tag is updated

2. Merge a PR whose commits include `fix: correct subnet CIDR`
   - Verify Git tag `v{NEXT_PATCH}` (e.g., `v1.0.1`) is created

3. Merge a PR containing `BREAKING CHANGE` in a commit footer
   - Verify Git tag `v{NEXT_MAJOR}` (e.g., `v2.0.0`) is created

4. Merge a PR whose commits are only `chore:` or `docs:` type
   - Verify **no new tag** is created

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
pinned version literal in every `uses:` line in `ci.yml`, `cd.yml`, and `release.yml` (e.g.,
`@v1.3.2` → `@v1.4.0`). GitHub Actions does not support env vars in `uses:` fields; the version
must be a literal string. A comment at the top of each workflow file tracks the current pinned version.
