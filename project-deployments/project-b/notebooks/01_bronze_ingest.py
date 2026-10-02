# Databricks notebook source
# MAGIC %md
# MAGIC # 01 — Bronze ingest (Phase 1)
# MAGIC
# MAGIC Spec: [phase-1-bronze-ingestion.md](../../../docs/developer/project-b/exercises/phase-1-bronze-ingestion.md)
# MAGIC
# MAGIC Fill the TODOs. Do **not** cleanse business quality here.

# COMMAND ----------

from pyspark.sql import functions as F
import uuid

CATALOG = "sar_sandbox_<you>"
LANDING = "abfss://landing@<storage_account>.dfs.core.windows.net/"
BATCH_ID = str(uuid.uuid4())

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.bronze")
spark.sql(f"USE CATALOG {CATALOG}")

# COMMAND ----------

def with_audit(df, batch_id: str):
    return (
        df.withColumn("_source_file", F.input_file_name())
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_batch_id", F.lit(batch_id))
        # TODO: optionally add _raw_payload
    )

# COMMAND ----------

# MAGIC %md
# MAGIC ## Officers

# COMMAND ----------

# TODO: read CSV from f"{LANDING}raw/reference/officers.csv"
# TODO: with_audit + write Delta to bronze.officers
# Hint: choose overwrite vs append carefully (see Phase 1 idempotency step)

# COMMAND ----------

# MAGIC %md
# MAGIC ## SAR requests

# COMMAND ----------

# TODO: read JSON array from f"{LANDING}raw/sar_requests/requests_2024.json"
# TODO: write bronze.sar_requests with audit columns
# Do NOT drop nulls / fix enums / rename requestor_id yet

# COMMAND ----------

# MAGIC %md
# MAGIC ## Status events + API logs

# COMMAND ----------

# TODO: bronze.status_events from raw/events/status_events.csv
# TODO: bronze.api_access_logs from raw/logs/api_access.jsonl (line-delimited JSON)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Idempotency experiment
# MAGIC 1. COUNT bronze.sar_requests
# MAGIC 2. Re-run this notebook
# MAGIC 3. COUNT again — fix if doubled; document your mechanism

# COMMAND ----------

# spark.table(f"{CATALOG}.bronze.sar_requests").count()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Micro-batches (guided)
# MAGIC Slice requests by created_at month and load with distinct _batch_id values.

# COMMAND ----------

# TODO: best-effort parse created_at; group by year-month; write per month

# COMMAND ----------

# MAGIC %md
# MAGIC ## Stretch — Auto Loader
# MAGIC Use checkpoints under checkpoints external location + 99_simulate_arrivals.py
