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

variable "aks_outbound_ip" {
  description = "AKS cluster outbound public IP address. Used for the PostgreSQL firewall rule to restrict database access to the AKS cluster. Sourced from the aks module aks_outbound_ip output."
  type        = string
}

variable "pg_admin_password" {
  description = "Administrator password for the PostgreSQL Flexible Server. Must be supplied via TF_VAR_pg_admin_password — never hardcode."
  type        = string
  sensitive   = true
}

variable "pg_admin_username" {
  description = "Administrator login name for the PostgreSQL Flexible Server."
  type        = string
  default     = "psqladmin"
}

variable "sku_name" {
  description = "SKU name for the PostgreSQL Flexible Server compute tier. Format: {tier}_{VM-series}. Example: GP_Standard_D2s_v3."
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "storage_mb" {
  description = "Maximum storage size in megabytes for the PostgreSQL Flexible Server."
  type        = number
  default     = 32768
}

variable "pg_version" {
  description = "PostgreSQL major version. Must be compatible with Temporal Server (13–16 supported)."
  type        = string
  default     = "16"
}
