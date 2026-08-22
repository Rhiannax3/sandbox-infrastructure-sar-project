# Shared Project B layer — apply once per Azure subscription/region.
#
# Copy to terraform.tfvars (gitignored):
#   cp example.tfvars terraform.tfvars
#
# Required:
#   databricks_account_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#
# Organizational tenant (greenfield metastore):
#   create_metastore      = true
#
# Personal MSA with bootstrap Premium workspace (metastore already exists):
#   create_metastore      = false
#   existing_metastore_id = "<metastore-uuid-from-account-console-catalog>"
#
# Optional:
#   budget_alert_email    = "mentor@example.com"

databricks_account_id = "00000000-0000-0000-0000-000000000000"
location              = "uksouth"
create_metastore      = true

# Personal MSA — uncomment and use instead of create_metastore = true:
# create_metastore      = false
# existing_metastore_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
