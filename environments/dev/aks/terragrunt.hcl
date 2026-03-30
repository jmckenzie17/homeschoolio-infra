# environments/dev/aks/terragrunt.hcl
# Dev AKS root — provisions a public AKS cluster with Workload Identity.

include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
}

terraform {
  source = "${get_repo_root()}//modules/azure-aks"
}

dependency "resource_group" {
  config_path = "../resource-group"
}

inputs = {
  environment         = "dev"
  owner               = "justin-mckenzie"
  resource_group_name = dependency.resource_group.outputs.resource_group_name
  node_count          = 1
  api_server_authorized_ip_ranges = ["107.5.5.52/32"]
}
