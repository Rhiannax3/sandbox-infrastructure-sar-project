# Platform administrator runbook

Provisioning guide for the SAR sandbox foundational infrastructure. Junior engineers do **not** run these steps; they consume the outputs.

**Projects A and B are independent.** An engineer (or cohort) may work on only one. You only need credentials and tooling for the cloud(s) you are provisioning, so each track has its own self-contained runbook — pick yours and work through it end to end.

| Track | Project | Cloud | Runbook |
|-------|---------|-------|---------|
| **AWS only** | A — API & Document Request System | AWS | [Project A (AWS) runbook](./project-a-aws-runbook.md) |
| **Azure only** | B — Medallion lake & reporting | Azure / Databricks | [Project B (Azure) runbook](./project-b-azure-runbook.md) |
| Both | Full programme | AWS + Azure | Work both runbooks; order does not matter |

There is **no runtime dependency** between the AWS portal/API sandbox and the Azure Databricks lake. Sample SAR data for Project B is generated and seeded in-repo (`seed-data/`); it does not require a live Project A stack.

Both runbooks assume Terraform `>= 1.9` and `make`, and both repeat the install steps for their own cloud so you never need to read the other track.

## Project A (AWS) at a glance

[Full runbook →](./project-a-aws-runbook.md)

**What you provision:** an isolated VPC and EC2 host per engineer (Terraform workspace = engineer id) running the Docker Compose stack (Caddy + Django SAR portal + Keycloak + Postgres), plus an S3 app artifact bucket, IAM baselines, SSM parameters for secrets and the API base URL, and an optional monthly budget. Lambda, API Gateway, and DynamoDB are deliberately left out — the junior builds those.

| Step | What happens |
|------|--------------|
| Tooling and credentials | Terraform, AWS CLI v2, Session Manager plugin; `AWS_PROFILE` + `aws sts get-caller-identity` |
| Bootstrap | `make bootstrap-aws` creates the remote state bucket, then you uncomment the S3 backend |
| Apply | `make plan-a` / `make apply-a ENGINEER=<id>` per engineer |
| Wait for first boot | Cloud-init needs **5–15 minutes** after apply before HTTPS answers |
| Verify | Portal loads, Keycloak realm responds, portal login as `officer.standard` |
| Handoff | Attach `junior_developer_policy_arn`; share `portal_url`, `lambda_execution_role_arn`, `api_base_url_parameter` |

**Recurring admin tasks:** redeploy the portal stack to a live host with `redeploy.sh`, flip `SAR_API_MODE` / `SAR_API_AUTH_ENABLED` in `/opt/sar-sandbox/.env` as the junior completes Phases 1 and 3, inspect the host over SSM, and manage auto-stop or teardown.

## Project B (Azure) at a glance

[Full runbook →](./project-b-azure-runbook.md)

**What you provision:** a shared stack holding the Databricks access connector and Unity Catalog metastore (create or adopt), then per engineer an ADLS Gen2 account with seeded landing data, a Databricks workspace assigned to the metastore, a catalog and external location, a cost-capped SQL warehouse, and persona groups.

| Step | What happens |
|------|--------------|
| Tooling and credentials | Terraform, Azure CLI (`pacman` on Arch/CachyOS), `az login`; **Databricks account admin** for the shared stack — [personal MSA signup guide](./personal-azure-databricks-setup.md) if needed |
| **New subscription** | Register `Microsoft.Storage`, `Microsoft.Databricks`, and related providers — [§1.3](./project-b-azure-runbook.md#13-new-azure-subscriptions) — before bootstrap |
| Bootstrap | `make bootstrap-azure` creates the state storage account, then you uncomment the azurerm backends |
| Shared apply | `make apply-b-shared` — set `databricks_account_id`; record `metastore_id` and access connector values |
| Engineer apply | `make apply-b ENGINEER=<id> METASTORE_ID=… ACCESS_CONNECTOR_*=…` |
| Handoff | Add the junior to `sar-<id>-data-engineers`; share workspace URL, catalog, external location, SQL warehouse JDBC URL |

**Recurring admin tasks:** regenerate seed data and refresh landing ([§4.1](./project-b-azure-runbook.md#41-regenerate-seed-data-and-refresh-landing-storage)), add or remove engineer sandboxes ([§5 Engineer sandbox lifecycle](./project-b-azure-runbook.md#5-engineer-sandbox-lifecycle)), leave the shared metastore in place while workspaces exist ([§4.2](./project-b-azure-runbook.md#42-shared-metastore-and-shared-stack-lifecycle)). Power BI licences remain a manual step.

## Related docs

- [Architecture overview](../architecture.md)
- [Project A engineer runbook](../developer/project-a/runbook.md)
- [Project B engineer runbook](../developer/project-b/runbook.md)
- [Seed data anomaly map](../mentor/anomaly-map.md) (mentor only)
- [Mentor deploy notes](../mentor/deploy-notes.md)
