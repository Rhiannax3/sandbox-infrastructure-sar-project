# Project B — Engineer runbook

Databricks Medallion Data Lake & SAR Reporting sandbox.

This track is **standalone** — you do not need an AWS / Project A sandbox. Landing data is pre-seeded from `seed-data/`.

**Learning path:** work the guided exercises in [`exercises/`](./exercises/README.md) (Phases 1–6). This runbook is the **environment reference**.

## What is already built for you

- ADLS Gen2 storage account with `landing`, `external`, `checkpoints` containers
- Landing container seeded with historical SAR JSON/CSV/JSONL (including quality issues)
- Databricks **Premium** workspace assigned to the shared Unity Catalog metastore
- Catalog `sar_sandbox_<you>` (empty of medallion schemas — you create them)
- External locations for landing, external, and checkpoints
- SQL warehouse (auto-stop 10 minutes) — your groups have `CAN_USE`
- Cost-capped **single-node** cluster policy — create clusters **only** under this policy
- Groups: `sar-<you>-data-engineers`, `sar-<you>-analysts`, `sar-<you>-report-authors`
- Event notification queue for Phase 6 push (file-notification) ingestion

## What you must build (by phase)

| Phase | You build |
|-------|-----------|
| 1 Bronze | Append-only ingestion into Delta; capture load metadata |
| 2 Silver | Cleanse, dedupe, quarantine pattern for bad records |
| 3 Gold | Kimball star schema (facts + dimensions) |
| 4 Platinum | Aggregations / business logic; Power BI dashboard |
| 5 Governance | RBAC: analysts → gold/platinum only; engineers → all layers |
| 6 Streaming | Pull vs push ingestion; near-real-time refresh with cost discipline |

## Getting started

```bash
terraform -chdir=terraform/project-b-azure-engineer workspace select <you>
terraform -chdir=terraform/project-b-azure-engineer output
```

Open `databricks_workspace_url`. Use cluster policy `cluster_policy_id` for interactive clusters.

Landing path: see `landing_external_location` (files under `raw/...`).
Checkpoints: `checkpoints_external_location`.
Import notebooks: [`project-deployments/project-b/notebooks/`](../../../project-deployments/project-b/notebooks/).

## Naming conventions (enforce from Gold onward)

Suggested (your mentor may refine):

- Schemas: `bronze`, `silver`, `gold`, `platinum`
- Tables: `fact_*`, `dim_*`, `agg_*`
- Columns: `snake_case`
- Keys: `<entity>_sk` (surrogate), `<entity>_id` (natural)

## Phase 5 starting point

Groups already exist. Grant at **schema/table** level on objects you own (catalog baseline is platform-managed). Example:

```sql
GRANT USE_SCHEMA, SELECT ON SCHEMA gold TO `sar-<you>-analysts`;
-- Do NOT grant bronze/silver to analysts
```

## Do not

- Delete or recreate the Unity Catalog metastore
- Create clusters outside the cost-capped policy / raise DBUs without mentor approval
- Leave continuous streaming queries running unsupervised (see Phase 6 cost warning)
- Expect Power BI licences to appear automatically — see [power-bi.md](power-bi.md)
