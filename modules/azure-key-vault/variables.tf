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
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "owner" {
  description = "Owner tag value — team or individual responsible for these resources."
  type        = string
  default     = "justin-mckenzie"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group in which to create all resources."
  type        = string
}

variable "eso_identity_principal_id" {
  description = "Principal (object) ID of the ESO user-assigned managed identity. Receives the Key Vault Secrets User role."
  type        = string
}

variable "pg_admin_password" {
  description = "PostgreSQL administrator password to store as a Key Vault secret. Must be supplied via TF_VAR_pg_admin_password."
  type        = string
  sensitive   = true
}

variable "pg_admin_username" {
  description = "PostgreSQL administrator username to store as a Key Vault secret."
  type        = string
  default     = "psqladmin"
}

variable "purge_protection_enabled" {
  description = "Whether to enable purge protection on the Key Vault. Immutable once set to true. Set false for dev (allows terraform destroy), true for staging/production."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted vault objects. Immutable after first apply. Range: 7–90."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}
