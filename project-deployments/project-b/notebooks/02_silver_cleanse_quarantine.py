# Databricks notebook source
# MAGIC %md
# MAGIC # 02 — Silver cleanse & quarantine (Phase 2)
# MAGIC
# MAGIC Spec: [phase-2-silver-quality.md](../../../docs/developer/project-b/exercises/phase-2-silver-quality.md)
# MAGIC
# MAGIC Layer A first: profile and list defects **before** coding quarantine rules.

# COMMAND ----------

from pyspark.sql import functions as F

CATALOG = "sar_sandbox_<you>"
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.silver")
spark.sql(f"USE CATALOG {CATALOG}")

requests = spark.table(f"{CATALOG}.bronze.sar_requests")
officers = spark.table(f"{CATALOG}.bronze.officers")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Layer A — Profile

# COMMAND ----------

# TODO: null rates, distinct request_id, sample weird values, date formats
display(requests.limit(20))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Layer B — Standardise
# MAGIC Trim ids; coalesce requestor_id / requester_id → officer_id; parse dates; cast sla_days.

# COMMAND ----------

# TODO: build standardised DataFrame `std_requests`

# COMMAND ----------

# MAGIC %md
# MAGIC ## Layer C — Deduplicate + survivorship

# COMMAND ----------

# TODO: define natural key + survivor rules

# COMMAND ----------

# MAGIC %md
# MAGIC ## Layer D — Validate + quarantine
# MAGIC Write silver.sar_requests and silver.sar_requests_exceptions (reason_code, reason_detail, ...).

# COMMAND ----------

# TODO: split good vs bad; write both tables idempotently

# COMMAND ----------

# MAGIC %md
# MAGIC ## Layer E — Reconciliation counts

# COMMAND ----------

# TODO: bronze count vs silver clean + exceptions (+ explain gaps)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Stretch — quality metrics + drift-tolerant aliases
