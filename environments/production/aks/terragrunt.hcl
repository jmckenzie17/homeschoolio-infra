# environments/production/aks/terragrunt.hcl
# Production AKS root — provisions a public AKS cluster with Workload Identity.

include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
}

terraform {
  source = "${get_repo_root()}//modules/azure-aks"
}

dependency "resource_group" {
  config_path = "../resource-group"
  mock_outputs_allowed_terraform_commands = ["plan"]
  mock_outputs = {
    resource_group_name = "mock-resource-group"
    resource_group_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-resource-group"
  }
}

inputs = {
  environment         = "production"
  owner               = "justin-mckenzie"
  resource_group_name = dependency.resource_group.outputs.resource_group_name
  node_count          = 3
  api_server_authorized_ip_ranges = ["107.5.5.52/32"]
}
