# environments/staging/resource-group/terragrunt.hcl
# Staging resource group root — deploys the azure-resource-group module.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}//modules/azure-resource-group"
}

inputs = {
  environment = "staging"
}
