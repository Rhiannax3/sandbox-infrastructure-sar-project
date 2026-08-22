-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 04 — Platinum business logic (Phase 4)
-- MAGIC
-- MAGIC Spec: [phase-4-platinum-business-logic.md](../../../docs/developer/project-b/exercises/phase-4-platinum-business-logic.md)
-- MAGIC Questions: [business-questions.md](../../../docs/developer/project-b/business-questions.md)

-- COMMAND ----------

CREATE SCHEMA IF NOT EXISTS sar_sandbox_<you>.platinum;
USE CATALOG sar_sandbox_<you>;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Define fulfilment_hours, sla_breach, backlog in comments before coding.

-- COMMAND ----------

-- TODO: platinum.agg_fulfilment_by_type_priority          -- Q1
-- TODO: platinum.agg_sla_breach_monthly                  -- Q2
-- TODO: platinum.agg_fulfilment_by_officer_role          -- Q3
-- TODO: platinum.agg_officer_open_close_weekly           -- Q4
-- TODO: platinum.agg_officer_reject_cancel_rate          -- Q5
-- TODO: platinum.agg_doc_type_by_officer_role            -- Q6
-- TODO: platinum.agg_api_error_rate_daily                -- Q7
-- TODO: platinum.agg_error_vs_backlog                    -- Q8
-- TODO: platinum.agg_api_latency_percentiles             -- Q9

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Stretch — Q10–12 scorecards + Power BI
-- MAGIC See power-bi.md. Prefer Import mode if warehouse auto-stop bites DirectQuery.
