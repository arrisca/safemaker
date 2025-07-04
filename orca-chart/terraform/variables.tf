variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "orca-chart"
}

variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, uat, prod."
  }
}

variable "datacenter" {
  description = "Datacenter location (GL, SL)"
  type        = string
  validation {
    condition     = contains(["GL", "SL"], var.datacenter)
    error_message = "Datacenter must be one of: GL, SL."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "resource_group" {
  description = "Azure resource group name"
  type        = string
  default     = ""
}

# PostgreSQL Variables
variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "postgres_admin"
}

variable "pg_password" {
  description = "PostgreSQL administrator password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

variable "postgres_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "postgres_backup_retention_days" {
  description = "PostgreSQL backup retention in days"
  type        = number
  default     = 7
}

variable "postgres_configurations" {
  description = "PostgreSQL configuration parameters"
  type        = map(string)
  default = {
    "max_connections"           = "100"
    "shared_preload_libraries" = "pg_stat_statements"
    "log_statement"            = "all"
    "log_min_duration_statement" = "1000"
  }
}

# Deployment flags
variable "deploy_airflow" {
  description = "Deploy Airflow database"
  type        = bool
  default     = true
}

variable "deploy_spark" {
  description = "Deploy Spark database"
  type        = bool
  default     = true
}

# Network Variables
variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "postgres_subnet_address_prefix" {
  description = "PostgreSQL subnet address prefix"
  type        = string
  default     = "10.0.1.0/24"
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}