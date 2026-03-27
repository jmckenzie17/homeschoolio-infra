# environments/production/terragrunt.hcl
# Environment-level config for production. Child roots in this directory include this file.

locals {
  environment = "production"
}
