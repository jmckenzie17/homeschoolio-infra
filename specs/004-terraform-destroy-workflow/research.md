# Research: Terraform Infrastructure Destroy Workflow

## Destroy Order for Terragrunt Roots

**Decision**: Destroy roots in reverse dependency order: `postgresql → key-vault → aks → resource-group`

**Rationale**: Resources must be destroyed before resources they depend on. The `resource-group` contains all other resources; destroying it last ensures Terraform state is consistent. The `postgresql`, `key-vault`, and `aks` roots all depend on `resource-group` outputs; `postgresql` and `key-vault` depend on `aks` outputs (outbound IP firewall rule, workload identity). Destroying in forward-dependency reverse order avoids Azure errors on resource-group deletion with dangling child resources.

**Alternatives considered**: `terragrunt run-all destroy` with automatic dependency resolution — rejected because `run-all destroy` in Terragrunt reverses the DAG automatically, but using it requires `--terragrunt-non-interactive` and any failure leaves the run-all in an indeterminate state with unclear per-root reporting. Explicit sequential invocation gives clear per-root pass/fail and audit output.

---

## Authentication for Destroy

**Decision**: Reuse existing OIDC authentication pattern (`id-token: write` permission + `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets).

**Rationale**: The existing `cd.yml` and CI workflows already authenticate via OIDC using these three secrets. The state backend (`homeschooliostfstate`) uses `use_oidc = true`. No new credentials are needed; the same federated identity can perform destroys.

**Alternatives considered**: Service principal with client secret — rejected as the repo already uses OIDC and adding a long-lived secret would be a security regression.

---

## Confirmation Guard Pattern

**Decision**: `workflow_dispatch` boolean input `confirm_destroy: true/false` (required, default `false`). Workflow checks the value in a pre-destroy gate step and exits non-zero if `false`.

**Rationale**: GitHub Actions `workflow_dispatch` boolean inputs render as a checkbox in the UI, giving a visible, intentional confirmation step. A step that asserts `confirm_destroy == 'true'` prevents accidental triggers. This is uniform across all environments per the spec decision (Option C).

**Alternatives considered**: String input requiring `"destroy"` typed — provides stronger accident-prevention but is less ergonomic for a boolean intent. String match is preferred for production-grade tools; for this POC, a checkbox is sufficient and consistent with the spec.

---

## Workflow Trigger

**Decision**: `workflow_dispatch` only. No automatic triggers.

**Rationale**: FR-001 explicitly prohibits automatic triggers. `workflow_dispatch` with required inputs is the standard GitHub Actions pattern for manual, gated operations.

---

## Per-Root Reporting

**Decision**: Each root runs in its own numbered step with a `continue-on-error: false` job step. The job writes a step summary using `$GITHUB_STEP_SUMMARY` with a markdown table of per-root results.

**Rationale**: GitHub Actions step summaries persist after the run and are visible to auditors. Sequential steps with explicit names (`Destroy postgresql`, `Destroy aks`, etc.) appear in the run log with clear pass/fail indicators.

---

## Concurrency

**Decision**: Use the same `cd-deployment` concurrency group as the existing `cd.yml`, with `cancel-in-progress: false`.

**Rationale**: Prevents a destroy from running concurrently with an apply on the same environment. `cancel-in-progress: false` ensures a running destroy is never silently cancelled by a new CD run, which could leave infrastructure in a partial state.

---

## PG Admin Password

**Decision**: Pass `TF_VAR_PG_ADMIN_PASSWORD` secret as an environment variable for the destroy steps, mirroring the `cd.yml` apply pattern.

**Rationale**: The `postgresql` module requires this variable even for destroy (Terraform must read the full configuration to plan and execute destroy). Without it, `tofu destroy` will error on variable validation.

---

## Tool Invocation

**Decision**: Use `opentofu/setup-opentofu@v1` and `gruntwork-io/terragrunt-action` (or direct `terragrunt` binary via PATH) consistent with the shared actions pattern. Each root is destroyed by `cd` into `environments/{env}/{root}` and running `terragrunt destroy -auto-approve`.

**Rationale**: This matches how the existing shared action workflows invoke terragrunt. `destroy -auto-approve` is appropriate here because the explicit confirmation gate earlier in the workflow substitutes for the interactive prompt.
