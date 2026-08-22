terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.0"
    }
    databricks = {
      source                = "databricks/databricks"
      version               = ">= 1.124"
      configuration_aliases = [databricks.accounts]
    }
  }
}
