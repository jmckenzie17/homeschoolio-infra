# environments/staging/infra/terragrunt.hcl
# Staging infrastructure root — deploys the example module.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}//modules/example"
}

inputs = {
  environment = "staging"
}
