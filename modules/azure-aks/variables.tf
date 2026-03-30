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

variable "api_server_authorized_ip_ranges" {
  description = "List of IPv4 CIDR ranges authorized to reach the public AKS API server. At least one CIDR is required; use [\"0.0.0.0/0\"] to allow all (not recommended for production). Example: [\"203.0.113.1/32\"]."
  type        = list(string)
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "VM SKU for the AKS node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "eso_namespace" {
  description = "Kubernetes namespace where the External Secrets Operator is deployed. Used to build the federated identity credential subject."
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_name" {
  description = "Name of the External Secrets Operator Kubernetes ServiceAccount. Used to build the federated identity credential subject."
  type        = string
  default     = "external-secrets"
}
