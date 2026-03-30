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
}

dependency "aks" {
  config_path = "../aks"
}

inputs = {
  environment         = "dev"
  owner               = "justin-mckenzie"
  resource_group_name = dependency.resource_group.outputs.resource_group_name
  aks_outbound_ip     = dependency.aks.outputs.aks_outbound_ip
  # pg_admin_password is supplied via TF_VAR_pg_admin_password environment variable.
  # Do not hardcode this value.
}
