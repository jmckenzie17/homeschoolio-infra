# modules/example/main.tf
# Example module — creates a tagged resource group.
# Used to validate the CI/CD pipeline end-to-end.

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc                   = true
  skip_provider_registration = true
}

resource "azurerm_resource_group" "this" {
  name     = "homeschoolio-${var.environment}-rg-example"
  location = var.location

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "opentofu"
    Owner       = var.owner
  }
}
