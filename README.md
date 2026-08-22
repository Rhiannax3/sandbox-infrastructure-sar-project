# SAR Sandbox Infrastructure

Foundational Terraform and application code for the Junior Data Engineering Development Programme — Architectural Sandbox Projects.

This repository provisions the **base infrastructure and boilerplate** that junior engineers build upon. It deliberately does **not** create the resources that are the learning objectives of each phase (Lambda, API Gateway, DynamoDB, medallion tables/pipelines, layer-level grants, Power BI dashboards).

**Project A (AWS) and Project B (Azure) are independent.** Provision and run only the track you need.

## Who should read what

| Role | Start here |
|------|------------|
| **Platform admin** — Project A only | [Project A (AWS) admin runbook](docs/platform-admin/project-a-aws-runbook.md) |
| **Platform admin** — Project B only | [Project B CLI runbook](docs/platform-admin/project-b-cli-runbook.md) (CLI/fish) · [Deployment stages](docs/platform-admin/project-b-deployment-stages.md) · [Azure runbook](docs/platform-admin/project-b-azure-runbook.md) |
| **Platform admin** — both tracks | [Platform administrator runbook summary](docs/platform-admin/runbook.md) |
| Junior — Project A | [Runbook](docs/developer/project-a/runbook.md) · [Exercises](docs/developer/project-a/exercises/phased-exercises.md) · [Lambda folder](project-deployments/project-a/README.md) |
| Junior — Project B | [Runbook](docs/developer/project-b/runbook.md) · [Exercises (Phases 1–6)](docs/developer/project-b/exercises/README.md) · [Notebooks](project-deployments/project-b/notebooks/) |

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
project-deployments/           # Engineer-built deploys (Project A Lambda + contracts)
seed-data/                     # Project B sample data (no AWS required)
docs/
```

## Prerequisites (by track)

Shared: Terraform `>= 1.9`, `make` — install steps are repeated in each admin runbook.

| Track | Also install |
|-------|----------------|
| **AWS / Project A** | AWS CLI v2 (Docker runs on the EC2 host, not locally) — [Project A admin runbook §1.2](docs/platform-admin/project-a-aws-runbook.md#12-aws-tooling) |
| **Azure / Project B** | Azure CLI + Databricks account admin — [Project B admin runbook §1.2](docs/platform-admin/project-b-azure-runbook.md#12-azure-tooling). Personal `@outlook.com` signup: [Databricks setup guide](docs/platform-admin/personal-azure-databricks-setup.md) first. |

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

Follow **[Project B deployment stages](docs/platform-admin/project-b-deployment-stages.md)** for first-time deploy (personal MSA, metastore adopt, recovery).

```bash
az login && az account set --subscription "<subscription-id-or-name>"
# Personal @outlook.com? See docs/platform-admin/personal-azure-databricks-setup.md first
make bootstrap-azure
# → uncomment azurerm backends; terraform.tfvars in shared + engineer roots
make apply-b-shared
make b-shared-env   # export METASTORE_ID=...
make apply-b ENGINEER=alex \
  METASTORE_ID=... \
  ACCESS_CONNECTOR_ID=... \
  ACCESS_CONNECTOR_PRINCIPAL_ID=...
```

Full reference: **[Project B (Azure) runbook](docs/platform-admin/project-b-azure-runbook.md)** · **[Deployment stages](docs/platform-admin/project-b-deployment-stages.md)**.

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
