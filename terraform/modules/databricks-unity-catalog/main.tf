variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "create_metastore" {
  type        = bool
  description = "Create a new UC metastore; set false to adopt an existing one"
  default     = true
}

variable "existing_metastore_id" {
  type        = string
  description = "Existing metastore ID when create_metastore is false"
  default     = ""
}

variable "metastore_owner" {
  type        = string
  description = "Account group or user that owns the metastore"
  default     = "account users"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Access connector (managed identity) for UC storage access
resource "azurerm_databricks_access_connector" "this" {
  name                = "dac-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Optional metastore-level storage (recommended for managed tables)
resource "azurerm_storage_account" "metastore" {
  count = var.create_metastore ? 1 : 0

  name                     = substr(replace("st${var.name_prefix}uc", "-", ""), 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "metastore" {
  count = var.create_metastore ? 1 : 0

  name                  = "metastore"
  storage_account_id    = azurerm_storage_account.metastore[0].id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "metastore_blob" {
  count = var.create_metastore ? 1 : 0

  scope                = azurerm_storage_account.metastore[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

resource "databricks_metastore" "this" {
  count = var.create_metastore ? 1 : 0

  name = "${var.name_prefix}-metastore"
  storage_root = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.metastore[0].name,
    azurerm_storage_account.metastore[0].name
  )
  region        = var.location
  owner         = var.metastore_owner
  force_destroy = true
}

resource "databricks_metastore_data_access" "this" {
  count = var.create_metastore ? 1 : 0

  metastore_id = databricks_metastore.this[0].id
  name         = "${var.name_prefix}-mi-dac"
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.this.id
  }
  is_default = true

  depends_on = [azurerm_role_assignment.metastore_blob]
}

locals {
  metastore_id = var.create_metastore ? databricks_metastore.this[0].id : var.existing_metastore_id
}

output "metastore_id" {
  value = local.metastore_id
}

output "access_connector_id" {
  value = azurerm_databricks_access_connector.this.id
}

output "access_connector_principal_id" {
  value = azurerm_databricks_access_connector.this.identity[0].principal_id
}

output "metastore_storage_account_name" {
  value = var.create_metastore ? azurerm_storage_account.metastore[0].name : null
}
