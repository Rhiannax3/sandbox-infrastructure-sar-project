# Mentor deploy notes

For the full platform setup (credentials, which files to edit, backends, per-engineer checklist), use:

**[Platform administrator runbook](../platform-admin/runbook.md)**

## Quick order of operations

1. AWS + Azure CLI login
2. `make bootstrap-aws` / `make bootstrap-azure` → uncomment backend blocks
3. `make apply-a ENGINEER=<id>`
4. Set `databricks_account_id` in `terraform/project-b-azure-shared/terraform.tfvars` → `make apply-b-shared`
5. `make apply-b ENGINEER=<id> METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=...`
6. Attach `junior_developer_policy_arn` to the junior’s IAM principal; add them to Databricks `sar-<id>-data-engineers`
7. Power BI licences remain manual — [power-bi.md](../project-b/power-bi.md)
