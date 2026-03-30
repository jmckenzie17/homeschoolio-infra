# environments/dev/key-vault/terragrunt.hcl
# Dev Key Vault root — provisions a Key Vault in RBAC mode with ESO Workload Identity.
#
# Prerequisites before applying:
#   export TF_VAR_pg_admin_password="<secure-password>"

include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
}

terraform {
  source = "${get_repo_root()}//modules/azure-key-vault"
}

dependency "resource_group" {
  config_path = "../resource-group"
}

dependency "aks" {
  config_path = "../aks"
}

inputs = {
  environment               = "dev"
  owner                     = "justin-mckenzie"
  resource_group_name       = dependency.resource_group.outputs.resource_group_name
  eso_identity_principal_id = dependency.aks.outputs.eso_identity_principal_id
  purge_protection_enabled  = false
  soft_delete_retention_days = 7
  # pg_admin_password is supplied via TF_VAR_pg_admin_password environment variable.
}
