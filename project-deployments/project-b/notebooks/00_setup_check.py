# Databricks notebook source
# MAGIC %md
# MAGIC # 00 — Setup check
# MAGIC
# MAGIC Run this before Phase 1. Attach a cluster created **under your cost-capped policy**.
# MAGIC Replace placeholders from `terraform output`.

# COMMAND ----------

# TODO: set from terraform outputs
CATALOG = "sar_sandbox_<you>"  # terraform output -raw catalog_name
LANDING = "abfss://landing@<storage_account>.dfs.core.windows.net/"  # landing_external_location
CHECKPOINTS = "abfss://checkpoints@<storage_account>.dfs.core.windows.net/"  # checkpoints_external_location

spark.sql(f"USE CATALOG {CATALOG}")
print("Catalog:", CATALOG)

# COMMAND ----------

display(dbutils.fs.ls(f"{LANDING}raw/"))

# COMMAND ----------

# MAGIC %md
# MAGIC Expect six paths under `raw/` (requests, truncated requests, events, logs, officers, manifest).

# COMMAND ----------

try:
    display(dbutils.fs.ls(CHECKPOINTS))
    print("Checkpoints location reachable")
except Exception as e:
    print("Checkpoints LIST failed — ask mentor to re-apply engineer stack:", e)

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Optional: wake SQL warehouse from a SQL editor with SELECT 1
# MAGIC SELECT current_catalog(), current_user()
