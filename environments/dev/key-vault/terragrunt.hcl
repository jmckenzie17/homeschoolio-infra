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
  mock_outputs_allowed_terraform_commands  = ["init", "plan"]
  mock_outputs_merge_strategy_with_state   = "shallow"
  mock_outputs = {
    resource_group_name = "mock-resource-group"
    resource_group_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-resource-group"
  }
}

dependency "aks" {
  config_path = "../aks"
  mock_outputs_allowed_terraform_commands  = ["init", "plan"]
  mock_outputs_merge_strategy_with_state   = "shallow"
  mock_outputs = {
    aks_cluster_name          = "mock-aks-cluster"
    aks_cluster_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-resource-group/providers/Microsoft.ContainerService/managedClusters/mock-aks-cluster"
    oidc_issuer_url           = "https://mock.oidc.issuer.example.com/"
    eso_identity_client_id    = "00000000-0000-0000-0000-000000000000"
    eso_identity_principal_id = "00000000-0000-0000-0000-000000000000"
    aks_outbound_ip           = "1.2.3.4"
  }
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
