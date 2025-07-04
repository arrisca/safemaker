terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  backend "azurerm" {
    # Configure remote state storage
    # These values should be set via environment variables or backend config
    # storage_account_name = "your-storage-account"
    # container_name       = "terraform-state"
    # key                  = "orca-chart.tfstate"
    # resource_group_name  = "your-rg"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "orca_rg" {
  name     = "${var.project_name}-${var.environment}-${var.datacenter}-rg"
  location = var.location
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Datacenter  = var.datacenter
    ManagedBy   = "terraform"
  }
}

# Random password for PostgreSQL
resource "random_password" "pg_password" {
  length  = 16
  special = true
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "orca_postgres" {
  name                   = "${var.project_name}-${var.environment}-${var.datacenter}-postgres"
  resource_group_name    = azurerm_resource_group.orca_rg.name
  location              = azurerm_resource_group.orca_rg.location
  version               = var.postgres_version
  administrator_login    = var.postgres_admin_username
  administrator_password = var.pg_password != "" ? var.pg_password : random_password.pg_password.result
  
  storage_mb = var.postgres_storage_mb
  sku_name   = var.postgres_sku_name
  
  backup_retention_days = var.postgres_backup_retention_days
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Datacenter  = var.datacenter
    ManagedBy   = "terraform"
  }
}

# PostgreSQL Database for Airflow
resource "azurerm_postgresql_flexible_server_database" "airflow_db" {
  count     = var.deploy_airflow ? 1 : 0
  name      = "airflow"
  server_id = azurerm_postgresql_flexible_server.orca_postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Database for Spark
resource "azurerm_postgresql_flexible_server_database" "spark_db" {
  count     = var.deploy_spark ? 1 : 0
  name      = "spark"
  server_id = azurerm_postgresql_flexible_server.orca_postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Virtual Network for private connectivity
resource "azurerm_virtual_network" "orca_vnet" {
  name                = "${var.project_name}-${var.environment}-${var.datacenter}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.orca_rg.location
  resource_group_name = azurerm_resource_group.orca_rg.name
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Datacenter  = var.datacenter
    ManagedBy   = "terraform"
  }
}

# Subnet for PostgreSQL
resource "azurerm_subnet" "postgres_subnet" {
  name                 = "postgres-subnet"
  resource_group_name  = azurerm_resource_group.orca_rg.name
  virtual_network_name = azurerm_virtual_network.orca_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres_dns" {
  name                = "${var.project_name}-${var.environment}-${var.datacenter}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.orca_rg.name
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Datacenter  = var.datacenter
    ManagedBy   = "terraform"
  }
}

# Link DNS Zone to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "postgres_dns_link" {
  name                  = "${var.project_name}-${var.environment}-${var.datacenter}-dns-link"
  resource_group_name   = azurerm_resource_group.orca_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres_dns.name
  virtual_network_id    = azurerm_virtual_network.orca_vnet.id
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Datacenter  = var.datacenter
    ManagedBy   = "terraform"
  }
}

# Configure PostgreSQL with private networking
resource "azurerm_postgresql_flexible_server_configuration" "orca_postgres_config" {
  depends_on = [azurerm_postgresql_flexible_server.orca_postgres]
  
  for_each = var.postgres_configurations
  
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.orca_postgres.id
  value     = each.value
}