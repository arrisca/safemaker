output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.orca_rg.name
}

output "resource_group_location" {
  description = "Location of the created resource group"
  value       = azurerm_resource_group.orca_rg.location
}

output "postgres_server_name" {
  description = "Name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.orca_postgres.name
}

output "postgres_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.orca_postgres.fqdn
}

output "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  value       = azurerm_postgresql_flexible_server.orca_postgres.administrator_login
}

output "postgres_admin_password" {
  description = "PostgreSQL administrator password"
  value       = azurerm_postgresql_flexible_server.orca_postgres.administrator_password
  sensitive   = true
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${azurerm_postgresql_flexible_server.orca_postgres.administrator_login}:${azurerm_postgresql_flexible_server.orca_postgres.administrator_password}@${azurerm_postgresql_flexible_server.orca_postgres.fqdn}:5432"
  sensitive   = true
}

output "airflow_database_name" {
  description = "Name of the Airflow database"
  value       = var.deploy_airflow ? azurerm_postgresql_flexible_server_database.airflow_db[0].name : null
}

output "spark_database_name" {
  description = "Name of the Spark database"
  value       = var.deploy_spark ? azurerm_postgresql_flexible_server_database.spark_db[0].name : null
}

output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.orca_vnet.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.orca_vnet.id
}

output "postgres_subnet_id" {
  description = "ID of the PostgreSQL subnet"
  value       = azurerm_subnet.postgres_subnet.id
}

output "private_dns_zone_name" {
  description = "Name of the private DNS zone"
  value       = azurerm_private_dns_zone.postgres_dns.name
}

# Output for Kubernetes secrets
output "postgres_secret_data" {
  description = "Data for Kubernetes secret containing PostgreSQL credentials"
  value = {
    POSTGRES_HOST     = azurerm_postgresql_flexible_server.orca_postgres.fqdn
    POSTGRES_PORT     = "5432"
    POSTGRES_USER     = azurerm_postgresql_flexible_server.orca_postgres.administrator_login
    POSTGRES_PASSWORD = azurerm_postgresql_flexible_server.orca_postgres.administrator_password
    POSTGRES_DB       = var.deploy_airflow ? azurerm_postgresql_flexible_server_database.airflow_db[0].name : "postgres"
  }
  sensitive = true
}

# Summary output
output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    project_name     = var.project_name
    environment      = var.environment
    datacenter       = var.datacenter
    location         = var.location
    postgres_version = var.postgres_version
    postgres_sku     = var.postgres_sku_name
    storage_mb       = var.postgres_storage_mb
    backup_retention = var.postgres_backup_retention_days
    deployed_at      = timestamp()
  }
}