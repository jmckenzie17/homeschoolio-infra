variable "project" {
  description = "Project name used in resource naming and tags."
  type        = string
  default     = "homeschoolio"
}

variable "environment" {
  description = "Environment tier (dev, staging, production)."
  type        = string
}

variable "location" {
  description = "Azure region for resources."
  type        = string
  default     = "eastus"
}

variable "owner" {
  description = "Owner tag value — team or individual responsible for these resources."
  type        = string
  default     = "justin-mckenzie"
}
