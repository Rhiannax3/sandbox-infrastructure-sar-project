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

variable "checkpoints_container_name" {
  type        = string
  description = "ADLS container for Auto Loader / streaming checkpoints"
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
  comment         = "External / quarantine / staging storage"
  depends_on      = [databricks_storage_credential.this]
}

resource "databricks_external_location" "checkpoints" {
  name = "${var.name_prefix}-checkpoints"
  url = format(
    "abfss://%s@%s.dfs.core.windows.net/",
    var.checkpoints_container_name,
    var.storage_account_name
  )
  credential_name = databricks_storage_credential.this.id
  comment         = "Auto Loader and Structured Streaming checkpoints"
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
  # Personal/trial subs often hit "Cluster Start-up Delayed" — create the warehouse
  # without waiting for RUNNING; it starts on first SQL query.
  no_wait = true

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

# Enforce the cost-capped policy: unrestricted allow_cluster_create is OFF;
# CAN_USE on the policy still permits cluster creation within the policy.
resource "databricks_permissions" "cluster_policy" {
  cluster_policy_id = databricks_cluster_policy.cost_capped.id

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_USE"
  }

  depends_on = [databricks_permission_assignment.data_engineers]
}

resource "databricks_permissions" "sql_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.warehouse.id

  access_control {
    group_name       = databricks_group.data_engineers.display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = databricks_group.analysts.display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = databricks_group.report_authors.display_name
    permission_level = "CAN_USE"
  }

  depends_on = [
    databricks_permission_assignment.data_engineers,
    databricks_permission_assignment.analysts,
    databricks_permission_assignment.report_authors,
  ]
}

# Persona groups for Phase 5 RBAC exercises (grants left to engineers).
# Unity Catalog grants require account-level groups, not workspace-local groups.
resource "databricks_group" "data_engineers" {
  provider     = databricks.accounts
  display_name = "${var.name_prefix}-data-engineers"
  force        = true
}

resource "databricks_group" "analysts" {
  provider     = databricks.accounts
  display_name = "${var.name_prefix}-analysts"
  force        = true
}

resource "databricks_group" "report_authors" {
  provider     = databricks.accounts
  display_name = "${var.name_prefix}-report-authors"
  force        = true
}

# group_name references the account group display name (avoids principal_id lookup issues).
resource "databricks_permission_assignment" "data_engineers" {
  group_name  = databricks_group.data_engineers.display_name
  permissions = ["USER"]
}

resource "databricks_permission_assignment" "analysts" {
  group_name  = databricks_group.analysts.display_name
  permissions = ["USER"]
}

resource "databricks_permission_assignment" "report_authors" {
  group_name  = databricks_group.report_authors.display_name
  permissions = ["USER"]
}

resource "databricks_entitlements" "data_engineers" {
  group_id                   = databricks_group.data_engineers.id
  workspace_access           = true
  databricks_sql_access      = true
  # Unrestricted cluster create bypasses the cost-capped policy — keep false.
  allow_cluster_create       = false
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
    principal = databricks_group.data_engineers.display_name
    privileges = [
      "USE_CATALOG",
      "BROWSE",
      "CREATE_SCHEMA",
      "USE_SCHEMA",
      "CREATE_TABLE",
      "SELECT",
      "MODIFY",
      "CREATE_FUNCTION",
      "EXECUTE",
      "CREATE_VOLUME",
      "READ_VOLUME",
      "WRITE_VOLUME",
      "APPLY_TAG",
    ]
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

resource "databricks_grants" "external_engineers" {
  external_location = databricks_external_location.external.id

  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES", "CREATE_EXTERNAL_TABLE"]
  }

  depends_on = [databricks_permission_assignment.data_engineers]
}

resource "databricks_grants" "checkpoints_engineers" {
  external_location = databricks_external_location.checkpoints.id

  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["READ_FILES", "WRITE_FILES"]
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

output "external_external_location" {
  value = databricks_external_location.external.url
}

output "checkpoints_external_location" {
  value = databricks_external_location.checkpoints.url
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
