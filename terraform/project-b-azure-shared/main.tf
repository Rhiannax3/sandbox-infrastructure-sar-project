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
  }

  # Uncomment after `make bootstrap-azure`:
  # backend "azurerm" {
  #   resource_group_name  = "rg-sar-sandbox-tfstate"
  #   storage_account_name = "REPLACE"
  #   container_name       = "tfstate"
  #   key                  = "project-b-shared/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

# Account-level Databricks provider for metastore management.
# Authenticate via Azure CLI (`az login`) or set DATABRICKS_ACCOUNT_ID + Azure SP.
provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  auth_type  = "azure-cli"
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "databricks_account_id" {
  type        = string
  description = "Azure Databricks account ID (UUID)"
}

variable "create_metastore" {
  type        = bool
  description = "Create a new regional UC metastore (one per region). Set false to adopt an existing metastore."
  default     = true
}

variable "existing_metastore_id" {
  type    = string
  default = ""
}

variable "metastore_owner" {
  type        = string
  description = "Metastore owner principal (account admin group or user)"
  default     = "account users"
}

variable "monthly_budget_gbp" {
  type    = number
  default = 150
}

variable "budget_alert_email" {
  type    = string
  default = ""
}

locals {
  name_prefix = "sar-shared"
  tags = {
    Project    = "sar-sandbox"
    ManagedBy  = "terraform"
    Layer      = "shared"
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

module "unity_catalog" {
  source = "../modules/databricks-unity-catalog"

  providers = {
    databricks = databricks.accounts
  }

  name_prefix           = local.name_prefix
  location              = module.foundation.location
  resource_group_name   = module.foundation.resource_group_name
  create_metastore      = var.create_metastore
  existing_metastore_id = var.existing_metastore_id
  metastore_owner       = var.metastore_owner
  tags                  = local.tags
}

# Azure Consumption Budget for the shared resource group
resource "azurerm_consumption_budget_resource_group" "shared" {
  count = var.budget_alert_email != "" ? 1 : 0

  name              = "${local.name_prefix}-monthly"
  resource_group_id = module.foundation.resource_group_id

  amount     = var.monthly_budget_gbp
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.budget_alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.budget_alert_email]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}

output "resource_group_name" {
  value = module.foundation.resource_group_name
}

output "metastore_id" {
  value = module.unity_catalog.metastore_id
}

output "access_connector_id" {
  value = module.unity_catalog.access_connector_id
}

output "access_connector_principal_id" {
  value = module.unity_catalog.access_connector_principal_id
}

output "location" {
  value = module.foundation.location
}
