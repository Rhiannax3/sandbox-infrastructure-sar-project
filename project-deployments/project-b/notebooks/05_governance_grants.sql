-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 05 — Governance grants (Phase 5)
-- MAGIC
-- MAGIC Spec: [phase-5-governance-rbac.md](../../../docs/developer/project-b/exercises/phase-5-governance-rbac.md)
-- MAGIC
-- MAGIC Grant at **schema/table** level on objects you own. Do not fight Terraform catalog grants.

-- COMMAND ----------

USE CATALOG sar_sandbox_<you>;

-- COMMAND ----------

-- Replace <you> with engineer id
-- GRANT USE_SCHEMA, SELECT ON SCHEMA gold TO `sar-<you>-analysts`;
-- GRANT USE_SCHEMA, SELECT ON SCHEMA platinum TO `sar-<you>-analysts`;
-- GRANT USE_SCHEMA, SELECT ON SCHEMA gold TO `sar-<you>-report-authors`;
-- GRANT USE_SCHEMA, SELECT ON SCHEMA platinum TO `sar-<you>-report-authors`;

-- Do NOT grant bronze/silver to analysts or report-authors

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Access-test matrix
-- MAGIC Record allow/deny evidence with mentor (second principal).

-- COMMAND ----------

-- SHOW GRANTS ON SCHEMA gold;
-- SHOW GRANTS ON SCHEMA bronze;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Stretch — mask subject_id + APPLY_TAG for PII
