# modules/azure-resource-group/main.tf
# Creates a tagged Azure resource group to serve as the container for homeschoolio resources.

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
  name     = "${var.project}-${var.environment}-rg-main"
  location = var.location

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "opentofu"
    Owner       = var.owner
  }
}
