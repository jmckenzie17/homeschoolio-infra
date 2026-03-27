# environments/dev/resource-group/terragrunt.hcl
# Dev resource group root — deploys the azure-resource-group module.

include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
}

terraform {
  source = "${get_repo_root()}//modules/azure-resource-group"
}

inputs = {
  environment = "dev"
}
