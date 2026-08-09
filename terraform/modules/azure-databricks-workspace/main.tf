variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_databricks_workspace" "this" {
  name                        = "dbw-${var.name_prefix}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  sku                         = "premium"
  managed_resource_group_name = "rg-${var.name_prefix}-dbx-managed"
  tags                        = var.tags
}

output "workspace_id" {
  value = azurerm_databricks_workspace.this.id
}

output "workspace_url" {
  value = azurerm_databricks_workspace.this.workspace_url
}

output "workspace_name" {
  value = azurerm_databricks_workspace.this.name
}

# Numeric workspace ID used by Databricks account APIs / metastore assignment
output "workspace_workspace_id" {
  value = azurerm_databricks_workspace.this.workspace_id
}
