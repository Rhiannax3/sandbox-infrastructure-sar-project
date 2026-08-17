# Mentor deploy notes

Full steps: **[Project A (AWS)](../platform-admin/project-a-aws-runbook.md)** · **[Project B (Azure)](../platform-admin/project-b-azure-runbook.md)**  
Projects are **independent** — run only the track the engineer needs.

## Project A only (AWS)

1. `export AWS_PROFILE=...` → `aws sts get-caller-identity`
2. `make bootstrap-aws` → uncomment S3 backend in `project-a-aws`
3. `make apply-a ENGINEER=<id>`
4. Attach `junior_developer_policy_arn` to their IAM principal

## Project B only (Azure)

1. `az login` → set subscription
2. `make bootstrap-azure` → uncomment azurerm backends
3. Set `databricks_account_id` in shared `terraform.tfvars` → `make apply-b-shared`
4. `make apply-b ENGINEER=<id> METASTORE_ID=... ACCESS_CONNECTOR_ID=... ACCESS_CONNECTOR_PRINCIPAL_ID=...`
5. Add user to Databricks `sar-<id>-data-engineers`
6. Power BI licences remain manual — [power-bi.md](../developer/project-b/power-bi.md)
