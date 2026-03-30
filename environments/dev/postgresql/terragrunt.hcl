# environments/dev/postgresql/terragrunt.hcl
# Dev PostgreSQL root — provisions a PostgreSQL Flexible Server with a public
# endpoint restricted to the AKS outbound IP via a firewall rule.
#
# Prerequisites before applying:
#   export TF_VAR_pg_admin_password="<secure-password>"

include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
}

terraform {
  source = "${get_repo_root()}//modules/azure-postgresql"
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
  environment         = "dev"
  owner               = "justin-mckenzie"
  resource_group_name = dependency.resource_group.outputs.resource_group_name
  aks_outbound_ip     = dependency.aks.outputs.aks_outbound_ip
  # pg_admin_password is supplied via TF_VAR_pg_admin_password environment variable.
  # Do not hardcode this value.
}
