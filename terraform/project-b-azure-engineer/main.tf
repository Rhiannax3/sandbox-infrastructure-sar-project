terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.124"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Uncomment after bootstrap:
  # backend "azurerm" {
  #   resource_group_name  = "rg-sar-sandbox-tfstate"
  #   storage_account_name = "REPLACE"
  #   container_name       = "tfstate"
  #   key                  = "project-b-engineer/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

# Workspace-level Databricks provider (after workspace exists)
provider "databricks" {
  host                        = "https://${module.workspace.workspace_url}"
  azure_workspace_resource_id = module.workspace.workspace_id
  auth_type                   = "azure-cli"
}

variable "engineer_id" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.engineer_id))
    error_message = "engineer_id must be 2-20 chars of lowercase alphanumeric and hyphens."
  }
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "metastore_id" {
  type        = string
  description = "Unity Catalog metastore ID from project-b-azure-shared output"
}

variable "access_connector_id" {
  type        = string
  description = "Databricks access connector resource ID from shared stack"
}

variable "access_connector_principal_id" {
  type        = string
  description = "Managed identity principal ID of the access connector"
}

variable "monthly_budget_gbp" {
  type    = number
  default = 100
}

variable "budget_alert_email" {
  type    = string
  default = ""
}

variable "seed_data_path" {
  type        = string
  description = "Path to committed seed-data/out directory (relative to this module)"
  default     = "../../../seed-data/out"
}

locals {
  name_prefix = "sar-${var.engineer_id}"
  tags = {
    Project    = "sar-sandbox"
    ManagedBy  = "terraform"
    Engineer   = var.engineer_id
    Programme  = "junior-de-sandbox"
    CostCenter = "training"
  }
}

module "foundation" {
  source = "../modules/azure-foundation"

  name_prefix = local.name_prefix
  location    = var.location
  tags        = local.tags
}

resource "random_string" "sa_suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "lake" {
  name                     = substr(replace("st${local.name_prefix}${random_string.sa_suffix.result}", "-", ""), 0, 24)
  resource_group_name      = module.foundation.resource_group_name
  location                 = module.foundation.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

resource "azurerm_storage_container" "landing" {
  name                  = "landing"
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "external" {
  name                  = "external"
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "checkpoints" {
  name                  = "checkpoints"
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

# Upload committed seed data into the landing container
resource "azurerm_storage_blob" "seed" {
  for_each = fileset(var.seed_data_path, "**/*")

  name                 = "raw/${each.value}"
  storage_container_id = azurerm_storage_container.landing.id
  type                 = "Block"
  source               = "${var.seed_data_path}/${each.value}"
  content_md5          = filemd5("${var.seed_data_path}/${each.value}")
}

module "workspace" {
  source = "../modules/azure-databricks-workspace"

  name_prefix         = local.name_prefix
  resource_group_name = module.foundation.resource_group_name
  location            = module.foundation.location
  tags                = local.tags
}

module "workspace_config" {
  source = "../modules/databricks-workspace-config"

  name_prefix                   = local.name_prefix
  engineer_id                   = var.engineer_id
  metastore_id                  = var.metastore_id
  workspace_id                  = module.workspace.workspace_workspace_id
  access_connector_id           = var.access_connector_id
  access_connector_principal_id = var.access_connector_principal_id
  storage_account_name          = azurerm_storage_account.lake.name
  storage_account_id            = azurerm_storage_account.lake.id
  landing_container_name        = azurerm_storage_container.landing.name
  external_container_name       = azurerm_storage_container.external.name

  depends_on = [module.workspace, azurerm_storage_blob.seed]
}

resource "azurerm_consumption_budget_resource_group" "engineer" {
  count = var.budget_alert_email != "" ? 1 : 0

  name              = "${local.name_prefix}-monthly"
  resource_group_id = module.foundation.resource_group_id
  amount            = var.monthly_budget_gbp
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.budget_alert_email]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}

output "resource_group_name" {
  value = module.foundation.resource_group_name
}

output "storage_account_name" {
  value = azurerm_storage_account.lake.name
}

output "landing_container" {
  value = azurerm_storage_container.landing.name
}

output "databricks_workspace_url" {
  value = "https://${module.workspace.workspace_url}"
}

output "catalog_name" {
  value = module.workspace_config.catalog_name
}

output "sql_warehouse_id" {
  value = module.workspace_config.sql_warehouse_id
}

output "sql_warehouse_jdbc_url" {
  value = module.workspace_config.sql_warehouse_jdbc_url
}

output "landing_external_location" {
  value = module.workspace_config.landing_external_location
}

output "group_data_engineers" {
  value = module.workspace_config.group_data_engineers
}

output "group_analysts" {
  value = module.workspace_config.group_analysts
}

output "group_report_authors" {
  value = module.workspace_config.group_report_authors
}

output "cluster_policy_id" {
  value = module.workspace_config.cluster_policy_id
}
