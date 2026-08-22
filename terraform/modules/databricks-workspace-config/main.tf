variable "name_prefix" {
  type = string
}

variable "engineer_id" {
  type = string
}

variable "metastore_id" {
  type = string
}

variable "workspace_id" {
  type        = string
  description = "Numeric Databricks workspace ID"
}

variable "access_connector_id" {
  type = string
}

variable "access_connector_principal_id" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "storage_account_id" {
  type = string
}

variable "landing_container_name" {
  type = string
}

variable "external_container_name" {
  type = string
}

variable "sql_warehouse_auto_stop_mins" {
  type    = number
  default = 10
}

variable "cluster_auto_terminate_mins" {
  type    = number
  default = 20
}

resource "databricks_metastore_assignment" "this" {
  metastore_id = var.metastore_id
  workspace_id = var.workspace_id
}

resource "azurerm_role_assignment" "landing_blob" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.access_connector_principal_id
}

resource "databricks_storage_credential" "this" {
  name = "${var.name_prefix}-storage-credential"
  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }
  comment    = "Managed identity credential for engineer ${var.engineer_id}"
  depends_on = [databricks_metastore_assignment.this, azurerm_role_assignment.landing_blob]
}

resource "databricks_external_location" "landing" {
  name = "${var.name_prefix}-landing"
  url = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    var.landing_container_name,
    var.storage_account_name
  )
  credential_name = databricks_storage_credential.this.id
  comment         = "Landing zone for raw SAR seed data"
  depends_on      = [databricks_storage_credential.this]
}

resource "databricks_external_location" "external" {
  name = "${var.name_prefix}-external"
  url = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    var.external_container_name,
    var.storage_account_name
  )
  credential_name = databricks_storage_credential.this.id
  comment         = "External / quarantine / checkpoint storage"
  depends_on      = [databricks_storage_credential.this]
}

resource "databricks_catalog" "sandbox" {
  name = "sar_sandbox_${replace(var.engineer_id, "-", "_")}"
  storage_root = format(
    "abfss://%s@%s.dfs.core.windows.net/catalog",
    var.external_container_name,
    var.storage_account_name
  )
  comment = "Sandbox catalog for engineer ${var.engineer_id}. Engineers create bronze/silver/gold/platinum schemas."
  properties = {
    purpose  = "training"
    engineer = var.engineer_id
  }
  depends_on = [databricks_external_location.external, databricks_metastore_assignment.this]
}

# Intentionally NO bronze/silver/gold/platinum schemas — engineers create these.

resource "databricks_sql_endpoint" "warehouse" {
  name                      = "${var.name_prefix}-sql"
  cluster_size              = "2X-Small"
  min_num_clusters          = 0
  max_num_clusters          = 1
  auto_stop_mins            = var.sql_warehouse_auto_stop_mins
  enable_serverless_compute = false
  warehouse_type            = "PRO"

  tags {
    custom_tags {
      key   = "Engineer"
      value = var.engineer_id
    }
  }

  timeouts {
    create = "45m"
  }

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_cluster_policy" "cost_capped" {
  name = "${var.name_prefix}-single-node"
  definition = jsonencode({
    "spark_version" : {
      "type" : "unlimited",
      "defaultValue" : "auto:latest-lts"
    },
    "node_type_id" : {
      "type" : "unlimited",
      "defaultValue" : "Standard_DS3_v2"
    },
    "num_workers" : {
      "type" : "fixed",
      "value" : 0,
      "hidden" : true
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : var.cluster_auto_terminate_mins,
      "defaultValue" : var.cluster_auto_terminate_mins
    },
    "dbus_per_hour" : {
      "type" : "range",
      "maxValue" : 4
    }
  })
}

# Persona groups for Phase 5 RBAC exercises (grants left to engineers).
# Unity Catalog grants require account-level groups, not workspace-local groups.
resource "databricks_group" "data_engineers" {
  provider     = databricks.accounts
  display_name = "${var.name_prefix}-data-engineers"
}

resource "databricks_group" "analysts" {
  provider     = databricks.accounts
  display_name = "${var.name_prefix}-analysts"
}

resource "databricks_group" "report_authors" {
  provider     = databricks.accounts
  display_name = "${var.name_prefix}-report-authors"
}

resource "databricks_permission_assignment" "data_engineers" {
  principal_id = databricks_group.data_engineers.id
  permissions  = ["USER"]
}

resource "databricks_permission_assignment" "analysts" {
  principal_id = databricks_group.analysts.id
  permissions  = ["USER"]
}

resource "databricks_permission_assignment" "report_authors" {
  principal_id = databricks_group.report_authors.id
  permissions  = ["USER"]
}

resource "databricks_entitlements" "data_engineers" {
  group_id                   = databricks_group.data_engineers.id
  workspace_access           = true
  databricks_sql_access      = true
  allow_cluster_create       = true
  allow_instance_pool_create = false

  depends_on = [databricks_permission_assignment.data_engineers]
}

resource "databricks_entitlements" "analysts" {
  group_id              = databricks_group.analysts.id
  workspace_access      = true
  databricks_sql_access = true

  depends_on = [databricks_permission_assignment.analysts]
}

resource "databricks_entitlements" "report_authors" {
  group_id              = databricks_group.report_authors.id
  workspace_access      = true
  databricks_sql_access = true

  depends_on = [databricks_permission_assignment.report_authors]
}

# Baseline: engineers can use the catalog; layer grants are a Phase 5 task
resource "databricks_grants" "catalog_engineers" {
  catalog = databricks_catalog.sandbox.name

  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["USE_CATALOG", "CREATE_SCHEMA", "USE_SCHEMA", "CREATE_TABLE", "SELECT", "MODIFY"]
  }

  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["USE_CATALOG"]
  }

  grant {
    principal  = databricks_group.report_authors.display_name
    privileges = ["USE_CATALOG"]
  }

  depends_on = [
    databricks_permission_assignment.data_engineers,
    databricks_permission_assignment.analysts,
    databricks_permission_assignment.report_authors,
  ]
}

resource "databricks_grants" "landing_engineers" {
  external_location = databricks_external_location.landing.id

  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }

  depends_on = [databricks_permission_assignment.data_engineers]
}

output "catalog_name" {
  value = databricks_catalog.sandbox.name
}

output "sql_warehouse_id" {
  value = databricks_sql_endpoint.warehouse.id
}

output "sql_warehouse_jdbc_url" {
  value = databricks_sql_endpoint.warehouse.jdbc_url
}

output "landing_external_location" {
  value = databricks_external_location.landing.url
}

output "cluster_policy_id" {
  value = databricks_cluster_policy.cost_capped.id
}

output "group_data_engineers" {
  value = databricks_group.data_engineers.display_name
}

output "group_analysts" {
  value = databricks_group.analysts.display_name
}

output "group_report_authors" {
  value = databricks_group.report_authors.display_name
}
