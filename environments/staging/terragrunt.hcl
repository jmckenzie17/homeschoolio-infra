# environments/staging/terragrunt.hcl
# Environment-level config for staging. Child roots in this directory include this file.

locals {
  environment = "staging"
}
