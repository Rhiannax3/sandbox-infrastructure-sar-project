# Power BI connectivity guide

Power BI **licences and workspaces are not provisioned by Terraform**. A mentor/admin must assign licences in Microsoft 365 admin centre.

## Prerequisites

1. Power BI Pro (or Premium Per User) licence for the engineer
2. Membership of the Databricks group `sar-<engineer>-report-authors` (and/or analysts)
3. SQL warehouse running (starts on first query; auto-stops after 10 minutes)

## Connect Power BI Desktop to Databricks

1. From Terraform outputs, copy `sql_warehouse_jdbc_url` and `databricks_workspace_url`
2. In Power BI Desktop: **Get data → Azure → Azure Databricks**
3. Enter workspace URL and HTTP path from the SQL warehouse connection details (Databricks UI → SQL Warehouse → Connection details)
4. Sign in with **Azure Active Directory**
5. Select the `gold` / `platinum` tables (once engineers have created them)

## Publishing

1. Publish to a Power BI workspace created by your mentor
2. Configure the gateway / cloud connection to use OAuth against Azure Databricks
3. Schedule refresh during working hours only (cost)

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Login succeeds but no catalogs | Missing `USE_CATALOG` / group membership |
| Tables missing | Gold/Platinum not built yet, or grants not applied (Phase 5) |
| Warehouse errors / timeouts | Warehouse auto-stopped — retry to wake it |
| Licence prompt | Admin has not assigned Power BI licence |
