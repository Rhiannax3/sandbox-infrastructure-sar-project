# SAR Sandbox Infrastructure

Foundational Terraform and application code for the Junior Data Engineering Development Programme — Architectural Sandbox Projects.

This repository provisions the **base infrastructure and boilerplate** that junior engineers build upon. It deliberately does **not** create the resources that are the learning objectives of each phase (Lambda, API Gateway, DynamoDB, medallion tables/pipelines, layer-level grants, Power BI dashboards).

**Project A (AWS) and Project B (Azure) are independent.** Provision and run only the track you need.

## Who should read what

| Role | Start here |
|------|------------|
| **Platform admin** — Project A only | [Admin runbook §3 (AWS)](docs/platform-admin/runbook.md#3-project-a--aws-only) |
| **Platform admin** — Project B only | [Admin runbook §4 (Azure)](docs/platform-admin/runbook.md#4-project-b--azure-only) |
| **Platform admin** — full guide | [Platform administrator runbook](docs/platform-admin/runbook.md) |
| Junior — Project A | [Project A runbook](docs/project-a/runbook.md) |
| Junior — Project B | [Project B runbook](docs/project-b/runbook.md) |

## Projects

| Project | Cloud | What this repo provisions | What engineers build |
|---------|-------|---------------------------|----------------------|
| **A** — AWS API & Document Request System | AWS | EC2 host (Django + Keycloak via Docker Compose), IAM baselines, SSM integration seam, log archive | Lambda, API Gateway, DynamoDB, JWT authorizer, resilience |
| **B** — Databricks Medallion & SAR Reporting | Azure | ADLS Gen2 + seeded data, Databricks workspace, Unity Catalog, SQL warehouse, persona groups | Bronze→Platinum layers, quarantine, Kimball model, RBAC grants, Power BI |

## Repository layout

```
terraform/
  bootstrap/{aws,azure}/       # Remote state backends (apply per cloud you use)
  project-a-aws/               # Project A only
  project-b-azure-shared/      # Project B shared (once per region)
  project-b-azure-engineer/    # Project B per engineer
  modules/
app/                           # Project A portal + Keycloak + Compose
contracts/                     # Shared JSON Schema (mainly Project A)
seed-data/                     # Project B sample data (no AWS required)
docs/
```

## Prerequisites (by track)

Shared: Terraform `>= 1.9`, `make` — [Admin §2](docs/platform-admin/runbook.md#2-shared-tooling)

| Track | Also install |
|-------|----------------|
| **AWS / Project A** | AWS CLI v2 (Docker runs on the EC2 host, not locally) — [Admin §3.1](docs/platform-admin/runbook.md#31-install-and-authenticate-aws) |
| **Azure / Project B** | Azure CLI + Databricks account admin — [Admin §4.1](docs/platform-admin/runbook.md#41-install-and-authenticate-azure) |

## Quick start

### Project A only (AWS)

```bash
export AWS_PROFILE=aws_sandbox   # your profile
aws sts get-caller-identity
make bootstrap-aws
# → uncomment S3 backend in terraform/project-a-aws/main.tf
make apply-a ENGINEER=alex
```

### Project B only (Azure)

```bash
az login && az account show
make bootstrap-azure
# → uncomment azurerm backends; set databricks_account_id in shared tfvars
make apply-b-shared
make apply-b ENGINEER=alex \
  METASTORE_ID=... \
  ACCESS_CONNECTOR_ID=... \
  ACCESS_CONNECTOR_PRINCIPAL_ID=...
```

Full file lists, handoff checklists, and troubleshooting: **[docs/platform-admin/runbook.md](docs/platform-admin/runbook.md)**.

## Isolation model

Each engineer gets an isolated stack via Terraform workspaces and `engineer_id`:

```hcl
local.name_prefix = "sar-${var.engineer_id}"
```

Use `make … ENGINEER=<id>` for routine deploys.

## Build boundary (do not provision)

- Lambda functions, API Gateway, DynamoDB
- Bronze / Silver / Gold / Platinum schemas, tables, pipelines
- Layer-level Unity Catalog grants
- Power BI dashboards and licences

## Cost guardrails

- EC2 auto-stop outside working hours (Project A)
- AWS Budgets / Azure Consumption Budget alerts (per track)
- SQL warehouse auto-stop + cost-capped cluster policy (Project B)

## Licence

Internal training use only.
