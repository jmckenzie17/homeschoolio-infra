# environments/dev/infra/terragrunt.hcl
# Dev infrastructure root — deploys the example module.

include "root" {
  path = "${get_repo_root()}/terragrunt.hcl"
}

terraform {
  source = "${get_repo_root()}//modules/example"
}

inputs = {
  environment = "dev"
}
