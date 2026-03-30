# Quickstart: Terraform Infrastructure Destroy Workflow

## What This Workflow Does

Destroys all Terraform-managed infrastructure for a selected environment (`dev`, `staging`, or `production`) via a manually triggered GitHub Actions workflow. Resources are destroyed in reverse dependency order; the workflow halts and reports failure if any root fails.

## How to Trigger

1. Navigate to **Actions** → **Destroy Infrastructure** in the GitHub repository.
2. Click **Run workflow**.
3. Select the target **Environment** (`dev`, `staging`, or `production`).
4. Check **Confirm destroy** to confirm destructive intent.
5. Click **Run workflow**.

> If **Confirm destroy** is not checked, the workflow exits immediately without destroying anything.

## Destroy Order

Resources are destroyed in this sequence per environment:

```
1. postgresql
2. key-vault
3. aks
4. resource-group
```

## Audit Trail

Every run is recorded in GitHub Actions history. The job summary includes:
- Triggering actor
- Selected environment
- Per-root success/failure status
- Timestamp and run URL

## Prerequisites

The following repository secrets must be configured (same as existing CI/CD):

| Secret | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | OIDC federated identity client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `TF_VAR_PG_ADMIN_PASSWORD` | PostgreSQL admin password (required by postgresql module) |

## Concurrency

The workflow uses the `cd-deployment` concurrency group. It will queue behind any running apply/deploy workflow and cannot run concurrently with one.
