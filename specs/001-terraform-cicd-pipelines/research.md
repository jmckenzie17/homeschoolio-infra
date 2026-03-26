# Research: OpenTofu/Terragrunt CI/CD Pipelines

**Feature**: 001-terraform-cicd-pipelines
**Date**: 2026-03-26

## 1. OpenTofu + Terragrunt in GitHub Actions

**Decision**: Use `opentofu/setup-opentofu@v1` with provider caching via
`actions/cache@v4` keyed on `.terraform.lock.hcl`. Run Terragrunt commands as
`terragrunt run-all <command>`. Detect changed environment roots using
`tj-actions/changed-files` filtering on `environments/**/*.hcl` and `modules/**/*.tf`.

**Rationale**: Native OpenTofu action provides version management. Provider caching
(AWS provider ~250MB) significantly reduces CI runtime. Lock-file-keyed cache ensures
deterministic builds. `run-all` with path filtering avoids unnecessary plans on
unaffected roots.

**Alternatives considered**:
- Docker container: less portable across runner types; extra image maintenance
- Pre-built binary on self-hosted runners: viable but adds runner management overhead
- Provider mirror: more complex network setup than lock-file caching

**Key details**:
- Cache path: `~/.terraform.d/plugin-cache` with env `TF_PLUGIN_CACHE_DIR`
- Terragrunt CI command sequence: `init` → `validate` → `plan --out=tfplan.binary` → `show -json tfplan.binary > tfplan.json`
- Changed-root detection: filter on `environments/{env}/**` paths from changed files

---

## 2. Reusable GitHub Actions Workflows

**Decision**: Define each pipeline stage (validate, test, plan, apply, tag) as a
`workflow_call` workflow in `homeschoolio-shared-workflows`. Reference from this repo
using `uses: homeschoolio/homeschoolio-shared-workflows/.github/workflows/{name}.yml@v{semver}`.
Pin to exact semver tag; upgrade via explicit PR bumping the tag reference.

**Rationale**: Semver pinning gives reproducibility and an audit trail for upgrades.
`workflow_call` with `inputs:` and `secrets:` provides type-safe parameter passing.
Avoids floating `@main` references which violate the constitution's immutable-versioning
principle.

**Alternatives considered**:
- Commit SHA pinning: maximum immutability but no human-readable version
- Floating `@main`: violates constitution, unpredictable breakage
- Floating `@v1` alias: convenience vs. reproducibility trade-off, not recommended

**Key details**:
- Max nesting depth: 10 levels; max unique reusable workflows per run: 50
- Secrets cannot be passed via `inputs:`; must use dedicated `secrets:` key
- Concurrency: only set at the called workflow level to avoid caller cancellation
- Upgrade path: open PR to this repo, bump `@v1.2.0` → `@v1.3.0`, review, merge

---

## 3. Infrastructure Testing Tools

**Decision**: Three-layer approach:
1. **tfsec** — fast static HCL scan, runs pre-plan for immediate feedback (blocks on CRITICAL/HIGH)
2. **Checkov** — plan JSON scan post-`terragrunt plan`, maximum context-awareness
3. **OPA/Conftest** — custom organizational policies (tag naming, resource naming) applied to plan JSON

**Rationale**: Layered approach catches issues at different stages. All three tools run
offline against HCL/plan JSON — no live cloud credentials required in CI. Checkov has
explicit OpenTofu support. tfsec provides fast early feedback. Conftest handles
org-specific rules not covered by built-in rulesets.

**Alternatives considered**:
- Terrascan alone: fewer built-in rules, less mature OPA integration
- Sentinel: requires Terraform Cloud/Enterprise, overkill for this setup
- Snyk: good for supply-chain risk but requires API calls (external dependency)
- Trivy: excellent for containers, weak on HCL/plan analysis

**Key details**:
- tfsec output: SARIF uploaded via `github/codeql-action/upload-sarif`; pipeline exits non-zero on CRITICAL/HIGH findings
- Checkov: `checkov -f tfplan.json --framework terraform_plan --compact --output sarif`
- Conftest: `conftest test tfplan.json -p policies/ --all-namespaces -o sarif`
- Tag compliance OPA rule: deny if `tags["Project"]`, `tags["Environment"]`,
  `tags["ManagedBy"]`, or `tags["Owner"]` missing from resource changes
- Policy files live under `policies/` in repo root (Conftest default discovery path)

---

## 4. Semantic Versioning + Git Tag Automation

**Decision**: Use the existing shared workflow
`jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml`
(pinned via `secrets: inherit`). It runs `semantic-release` driven by conventional
commits (`feat:` → minor, `fix:` → patch, `BREAKING CHANGE` footer → major).
Creates `v{MAJOR.MINOR.PATCH}` tags plus a floating `v{MAJOR}` pointer on every
qualifying merge to `main`.

**Rationale**: The workflow already exists and is maintained in the shared-actions
repo — no need to build or maintain a custom tagging script. `semantic-release` is
the industry standard for conventional-commit-driven versioning and produces consistent,
auditable release history. Eliminates the manual `version.tf` bump pattern entirely.

**Alternatives considered**:
- Custom `tag.yml` with `git diff` on `version.tf`: built earlier in this session;
  superseded by the existing shared workflow which is more powerful and already maintained
- `mathieudutour/github-tag-action`: simpler but less standard; no changelog generation
- Manual tagging: no automation, defeats the feature's purpose

**Key details**:
- Caller: `.github/workflows/release.yml` — triggered on `push` to `main`
- Shared workflow ref: `jmckenzie17/homeschoolio-shared-actions/.github/workflows/semver-release.yml@main`
- Inputs: `release-branch: main`, `tag-prefix: "v"`
- Secrets: `inherit` (passes `GITHUB_TOKEN` automatically)
- Outputs: `release-created` (string `"true"`/`"false"`), `tag-name` (e.g., `v1.2.3`), `major-tag` (e.g., `v1`)
- Commit convention: Angular/conventional commits required (`feat:`, `fix:`, `chore:`, `BREAKING CHANGE`)
- No release created for `chore:`, `docs:`, `style:` commits — `release-created` will be `"false"`
- A `.releaserc.json` in this repo can override the default config if custom plugins are needed

---

## 5. GitHub Environment Protection Rules

**Decision**: Create three GitHub environments (`dev`, `staging`, `production`) via
GitHub repository Settings UI. `production` gets required-reviewer protection.
Reference environments in CD workflow jobs via `environment: {name}` key. GitHub
Actions pauses the `production-apply` job until a designated reviewer approves in
the Actions UI.

**Rationale**: Native GitHub platform feature — no custom tooling. Provides clear
audit trail (who approved, when). Integrates directly with GitHub notifications.
Environment secrets (e.g., `PROD_AWS_ROLE_ARN`) are scoped to their environment job,
reducing credential blast radius.

**Alternatives considered**:
- Custom `/approve-prod` comment trigger: shifts approval logic into pipeline code,
  harder to audit
- Third-party approval services (ServiceNow): enterprise-grade but excessive for this
  stack
- Branch protection rules: gates merges, not deployments; less granular

**Key details**:
- `dev`: no protection rules; `staging`: no protection rules (manual dispatch trigger
  is the gate); `production`: required reviewers (1+ from designated team/users)
- Deployment branch restriction on `production`: restrict to `main` ref only
- Environment secrets scoped per environment: `DEV_AWS_ROLE_ARN`, `STAGING_AWS_ROLE_ARN`,
  `PROD_AWS_ROLE_ARN` stored in respective environment secret stores
- Wait timer on `production` (optional): configurable in GitHub UI, e.g., 60 minutes
  for manual smoke-test window after staging
- Rejection by reviewer causes job failure and halts CD chain (no further promotion)
