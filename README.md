# SAR Sandbox Infrastructure

Foundational Terraform and application code for the Junior Data Engineering Development Programme — Architectural Sandbox Projects.

This repository provisions the **base infrastructure and boilerplate** that junior engineers build upon. It deliberately does **not** create the resources that are the learning objectives of each phase (Lambda, API Gateway, DynamoDB, medallion tables/pipelines, layer-level grants, Power BI dashboards).

## Who should read what

| Role | Start here |
|------|------------|
| **Platform admin / senior architect** (you provision sandboxes) | **[Platform administrator runbook](docs/platform-admin/runbook.md)** — credentials, which files to edit, full deploy sequence |
| Junior engineer (Project A) | [Project A runbook](docs/project-a/runbook.md) |
| Junior engineer (Project B) | [Project B runbook](docs/project-b/runbook.md) |

## Projects

| Project | Cloud | What this repo provisions | What engineers build |
|---------|-------|---------------------------|----------------------|
| **A** — AWS API & Document Request System | AWS | EC2 host (Django + Keycloak via Docker Compose), IAM baselines, SSM integration seam, log archive | Lambda, API Gateway, DynamoDB, JWT authorizer, resilience |
| **B** — Databricks Medallion & SAR Reporting | Azure | ADLS Gen2 + seeded data, Databricks workspace, Unity Catalog, SQL warehouse, persona groups | Bronze→Platinum layers, quarantine, Kimball model, RBAC grants, Power BI |

## Repository layout

```
terraform/
  bootstrap/{aws,azure}/       # Remote state backends (apply once)
  project-a-aws/               # Per-engineer AWS sandbox
  project-b-azure-shared/      # Shared UC metastore (apply once)
  project-b-azure-engineer/    # Per-engineer Azure/Databricks sandbox
  modules/                     # Reusable Terraform modules
app/
  django-sar-portal/           # Django SAR compliance portal
  keycloak/                    # Pre-seeded realm export
  compose/                     # Docker Compose + Caddy
contracts/                     # JSON Schema data contracts
seed-data/                     # Generator + committed sample data
docs/                          # Runbooks, C4 skeleton, business questions
```

## Prerequisites

Install and authenticate these before applying (full steps: [Platform administrator runbook §2](docs/platform-admin/runbook.md#2-install-clis-and-libraries)):

- Terraform `>= 1.9`
- AWS CLI v2 (Project A)
- Azure CLI (`az login`) + Databricks **account admin** (Project B)
- Docker Engine + Compose plugin (app packaging / host stack)
- `make` and Python `>= 3.11` (seed data)
- Optional: TFLint, Checkov, pre-commit, Databricks CLI

## Platform admin — settings and credentials at a glance

Full detail: **[docs/platform-admin/runbook.md](docs/platform-admin/runbook.md)**.

**Credentials (CLI / environment — never commit):**

| Auth | Used for |
|------|----------|
| AWS profile / SSO / keys | Bootstrap AWS + Project A |
| `az login` (+ correct subscription) | Bootstrap Azure + Project B (Databricks uses `azure-cli` auth) |

**Files to update before / during first deploy:**

| File | What to set |
|------|-------------|
| `terraform/bootstrap/aws` — `state_bucket_name` if default is taken | Globally unique S3 bucket |
| `terraform/project-*-*/main.tf` — uncomment `backend` blocks | Paste snippets from bootstrap `terraform output` |
| `terraform/project-b-azure-shared/terraform.tfvars` (from `example.tfvars`) | **`databricks_account_id`** (required); optional metastore adopt + budget email |
| `terraform/project-a-aws/terraform.tfvars` (optional, from `example.tfvars`) | `budget_alert_email`, `allowed_ingress_cidrs` |
| `terraform/project-b-azure-engineer` — Makefile vars or tfvars | Shared outputs: `METASTORE_ID`, `ACCESS_CONNECTOR_ID`, `ACCESS_CONNECTOR_PRINCIPAL_ID` |
| `app/compose/.env` (from `.env.example`) | **Local Compose only** — not required for cloud apply |

## Quick start (admins)

```bash
# 1. CLI login
aws sts get-caller-identity
az account show

# 2. Remote state (once per cloud)
make bootstrap-aws
make bootstrap-azure
# → uncomment backend blocks using terraform output snippets

# 3. Project A (per engineer)
make apply-a ENGINEER=alex

# 4. Project B shared (once), then per engineer
cp terraform/project-b-azure-shared/example.tfvars \
   terraform/project-b-azure-shared/terraform.tfvars
# edit databricks_account_id
make apply-b-shared
make apply-b ENGINEER=alex \
  METASTORE_ID=... \
  ACCESS_CONNECTOR_ID=... \
  ACCESS_CONNECTOR_PRINCIPAL_ID=...
```

Then attach each junior’s IAM policy / Databricks group membership and (for Phase 4) Power BI licences — see the [admin runbook](docs/platform-admin/runbook.md).

## Isolation model

Each engineer gets an isolated stack via Terraform workspaces and an `engineer_id` variable:

```hcl
local.name_prefix = "sar-${var.engineer_id}"
```

All resources are named and tagged with this prefix. Use `make … ENGINEER=<id>` so operators do not need to manage `-var-file` / `-backend-config` flags by hand for routine deploys.

## Build boundary (do not provision)

- Lambda functions, API Gateway, DynamoDB
- Bronze / Silver / Gold / Platinum schemas, tables, pipelines
- Layer-level Unity Catalog grants
- Power BI dashboards and licences

## Cost guardrails

- EC2 auto-stop outside working hours (EventBridge)
- AWS Budgets + Azure Consumption Budget alerts
- SQL warehouse auto-stop (10 minutes)
- Cluster policy: single-node, 20-minute auto-terminate

## Licence

Internal training use only.
