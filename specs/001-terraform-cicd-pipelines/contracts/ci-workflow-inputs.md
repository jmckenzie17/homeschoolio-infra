# Contract: CI Workflow Inputs/Outputs

**Workflow file**: `.github/workflows/ci.yml` (caller, in this repo)
**Triggered by**: `pull_request` events on `main` branch; `push` to `main`

## Inputs (passed to shared workflows)

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `opentofu-version` | string | No | `1.6.x` | OpenTofu CLI version to install |
| `terragrunt-version` | string | No | `0.56.x` | Terragrunt CLI version to install |
| `checkov-version` | string | No | `latest` | Checkov version for plan scanning |
| `tfsec-version` | string | No | `latest` | tfsec version for static scanning |
| `environments` | string | No | `dev,staging,production` | Comma-separated list of env roots to plan |

## Secrets (passed to shared workflows)

| Secret | Required | Description |
|--------|----------|-------------|
| `github-token` | Yes | For PR commenting, SARIF upload, and artifact publishing |
| `opentofu-init-credentials` | Conditional | Backend credentials if init requires auth |

## Outputs (from shared workflows back to caller)

| Output | Source Job | Description |
|--------|-----------|-------------|
| `plan-has-destructive-ops` | `plan` job | `true` if any plan contains destroys/replacements |
| `affected-roots` | `plan` job | Comma-separated list of changed environment root paths |
| `validation-passed` | `validate` job | `true` if all roots pass `tofu validate` |
| `tests-passed` | `test` job | `true` if tfsec + Checkov + Conftest all pass |

## Job Sequence

```
validate (shared: validate.yml@vX.Y.Z)
    │
    └──► test (shared: test.yml@vX.Y.Z)
              │
              └──► plan (shared: plan.yml@vX.Y.Z)
                        │
                        └──► destructive-op-check (local inline step)
```

## Merge Gate Requirements

All of the following MUST be `true` before PR merge is allowed:
1. `validate` job: success
2. `test` job: success (zero CRITICAL/HIGH findings)
3. `plan` job: success (plan generated for all affected roots)
4. If `plan-has-destructive-ops == true`: PR description MUST contain acknowledgment
   marker (e.g., `- [x] I acknowledge destructive operations in this plan`)
