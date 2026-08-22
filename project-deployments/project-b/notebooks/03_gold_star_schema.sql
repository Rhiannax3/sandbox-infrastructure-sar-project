-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 03 — Gold star schema (Phase 3)
-- MAGIC
-- MAGIC Spec: [phase-3-gold-dimensional-model.md](../../../docs/developer/project-b/exercises/phase-3-gold-dimensional-model.md)
-- MAGIC
-- MAGIC Run against the SQL warehouse. Replace `sar_sandbox_<you>`.

-- COMMAND ----------

CREATE SCHEMA IF NOT EXISTS sar_sandbox_<you>.gold;
USE CATALOG sar_sandbox_<you>;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Declare grains (comments for your mentor)
-- MAGIC - fact_sar_request: ...
-- MAGIC - fact_status_event: ...
-- MAGIC - fact_api_call: ...

-- COMMAND ----------

-- TODO: CREATE OR REPLACE TABLE gold.dim_officer AS ...
-- TODO: gold.dim_document_type, gold.dim_status, gold.dim_date

-- COMMAND ----------

-- TODO: CREATE OR REPLACE TABLE gold.fact_sar_request AS ...
-- TODO: gold.fact_status_event, gold.fact_api_call

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Prove joins for business questions 1–6

-- COMMAND ----------

-- TODO: sample SELECT joining facts to dims

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Stretch — SCD2 dim_officer / accumulating snapshot design
