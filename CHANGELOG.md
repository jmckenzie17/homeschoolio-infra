# Changelog

All notable changes to homeschoolio-infra are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.0] — 2026-03-26

### Added

- CI/CD pipeline infrastructure for OpenTofu/Terragrunt on Microsoft Azure
  - `ci.yml` — PR trigger workflow: validate → test → plan → destructive-op gate
  - `cd.yml` — Merge promotion workflow: dev (auto) → staging → production (env gates)
  - `release.yml` — Semantic version release via conventional commits
- Shared reusable workflows published to `jmckenzie17/homeschoolio-shared-actions@v1.0.0`
  - `validate.yml` — HCL format check + OpenTofu validation with provider caching
  - `test.yml` — tfsec (static HCL), Checkov (plan JSON), OPA/Conftest (custom policies)
  - `plan.yml` — Changed-root detection, plan generation, PR comment, artifact upload
  - `apply.yml` — Pre-apply verification + `terragrunt run-all apply` with Azure OIDC
- OPA/Conftest policies in `policies/`
  - `tags.rego` — Required tag enforcement: `Project`, `Environment`, `ManagedBy`, `Owner`
  - `naming.rego` — Naming convention: `{project}-{environment}-{resource-type}-{descriptor}`
- `CONTRIBUTING.md` with conventional commit guidelines and version bump reference table
- Module version template at `modules/example/version.tf`
- Repository tooling: `.opentofu-version` (1.6.2), `.terragrunt-version` (0.56.3), `.gitignore`

---

<!-- Module versions are tracked separately as Git tags: modules/{name}/{version} -->
