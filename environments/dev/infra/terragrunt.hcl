# environments/dev/infra/terragrunt.hcl
# Dev infrastructure root — deploys the example module.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}//modules/example"
}

inputs = {
  environment = "dev"
}
