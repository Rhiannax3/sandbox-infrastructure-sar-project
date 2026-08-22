# Per-engineer Project B stack — one terraform workspace per ENGINEER=id.
#
# Copy to terraform.tfvars (gitignored):
#   cp example.tfvars terraform.tfvars
#
# All fields below are REQUIRED (Makefile METASTORE_ID / ACCESS_CONNECTOR_* env
# vars override metastore_id / access_connector_* if also passed on CLI):
#
#   engineer_id                   = "alex"
#   databricks_account_id         = "<same UUID as project-b-azure-shared>"
#   location                      = "uksouth"
#   metastore_id                  = "<from: make b-shared-env>"
#   access_connector_id           = "<from: make b-shared-env>"
#   access_connector_principal_id = "<from: make b-shared-env>"
#   budget_alert_email            = "mentor@example.com"   # REQUIRED (cost guardrail)

engineer_id = "demo"
location    = "uksouth"

databricks_account_id = "REPLACE_DATABRICKS_ACCOUNT_ID"

metastore_id                  = "REPLACE_METASTORE_ID"
access_connector_id           = "REPLACE_ACCESS_CONNECTOR_ID"
access_connector_principal_id = "REPLACE_PRINCIPAL_ID"
budget_alert_email            = "REPLACE_BUDGET_ALERT_EMAIL"
