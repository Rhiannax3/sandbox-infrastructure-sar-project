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
3. **New subscription?** Register providers — including **`Microsoft.EventGrid`** — [runbook §1.3](../platform-admin/project-b-azure-runbook.md#13-new-azure-subscriptions)
4. `make bootstrap-azure` → uncomment azurerm backends
5. Shared + engineer `terraform.tfvars` → `make apply-b-shared`
6. Engineer tfvars **must** set `budget_alert_email` (required) and `databricks_account_id`
7. `make b-shared-env` → `make apply-b ENGINEER=<id> ...`
8. **Re-apply after exercise infra updates:** checkpoints external location, warehouse/policy permissions, Event Grid queue — required **before Phase 1**
9. **Failed apply?** [Stage 5R](../platform-admin/project-b-deployment-stages.md#stage-5r--recover-from-failed-engineer-apply) — keep workspace, fix groups, re-apply
10. Add user to account group `sar-<id>-data-engineers` (account console → User management)
11. Import starter notebooks: `make b-notebooks ENGINEER=<id>` or see [`project-deployments/project-b/notebooks/README.md`](../../project-deployments/project-b/notebooks/README.md)
12. Power BI licences remain manual — [power-bi.md](../developer/project-b/power-bi.md)

### Verify as the junior (not as admin)

See [mentor Project B README — pre-handover verification](./project-b/README.md#pre-handover-verification-as-a-non-admin-data-engineer).

### Facilitation

Guided exercises: [developer exercises](../developer/project-b/exercises/README.md)  
Mentor rubrics: [mentor/project-b](./project-b/README.md)
