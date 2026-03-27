# modules/example/main.tf
# Example module — creates a tagged resource group.
# Used to validate the CI/CD pipeline end-to-end.

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
