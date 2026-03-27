# Root terragrunt.hcl — shared backend generation and common locals.
# All environment roots inherit from this file via find_in_parent_folders().

locals {
  project  = "homeschoolio"
  location = "eastus"

  storage_account = "homeschooliostfstate"
  resource_group  = "homeschoolio-shared-rg-tfstate"

  # Derive environment from the relative path: environments/{env}/...
  # path_relative_to_include() returns "" when evaluated at the root itself,
  # so we guard with a fallback to avoid an out-of-bounds index.
  path_parts  = split("/", path_relative_to_include())
  environment = length(local.path_parts) > 1 ? local.path_parts[1] : "unknown"
}

# Remote state: one container per environment root.
# Container name format: homeschoolio-{env}-infra-tfstate
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = local.resource_group
    storage_account_name = local.storage_account
    container_name       = "${local.project}-${local.environment}-infra-tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Common inputs passed to all child modules.
inputs = {
  project     = local.project
  environment = local.environment
  location    = local.location
}
