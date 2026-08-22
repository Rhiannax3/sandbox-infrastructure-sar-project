# Mentor deploy notes

Full steps: **[Project A (AWS)](../platform-admin/project-a-aws-runbook.md)** · **[Project B (Azure)](../platform-admin/project-b-azure-runbook.md)**  
Projects are **independent** — run only the track the engineer needs.

## Project A only (AWS)

1. `export AWS_PROFILE=...` → `aws sts get-caller-identity`
2. `make bootstrap-aws` → uncomment S3 backend in `project-a-aws`
3. `make apply-a ENGINEER=<id>`
4. Attach `junior_developer_policy_arn` to their IAM principal

## Project B only (Azure)

**First deploy:** follow **[Project B deployment stages](../platform-admin/project-b-deployment-stages.md)**.

1. **Personal MSA signup?** [Personal Azure — Databricks setup](../platform-admin/personal-azure-databricks-setup.md) (account console + account ID; expect metastore adopt).
2. `az login` → set subscription
3. **New subscription?** Register providers — [runbook §1.3](../platform-admin/project-b-azure-runbook.md#13-new-azure-subscriptions)
4. `make bootstrap-azure` → uncomment azurerm backends
5. Shared + engineer `terraform.tfvars` → `make apply-b-shared`
6. `make b-shared-env` → `make apply-b ENGINEER=<id> ...`
7. **Failed apply?** [Stage 5R](../platform-admin/project-b-deployment-stages.md#stage-5r--recover-from-failed-engineer-apply) — keep workspace, fix groups, re-apply
8. Add user to account group `sar-<id>-data-engineers` (account console → User management)
9. Power BI licences remain manual — [power-bi.md](../developer/project-b/power-bi.md)
