# Databricks notebook source
# MAGIC %md
# MAGIC # 06 — Streaming & near-real-time (Phase 6)
# MAGIC
# MAGIC Spec: [phase-6-streaming-near-real-time.md](../../../docs/developer/project-b/exercises/phase-6-streaming-near-real-time.md)
# MAGIC
# MAGIC **COST:** Prefer `Trigger.AvailableNow`. Continuous streams need mentor supervision and a hard stop.

# COMMAND ----------

from pyspark.sql import functions as F
from pyspark.sql.streaming import Trigger

CATALOG = "sar_sandbox_<you>"
LANDING = "abfss://landing@<storage_account>.dfs.core.windows.net/"
CHECKPOINTS = "abfss://checkpoints@<storage_account>.dfs.core.windows.net/"
# terraform output -raw autoloader_notification_queue_name / storage account
QUEUE_NAME = "autoloader-notifications"
STORAGE_ACCOUNT = "<storage_account>"

incoming = f"{LANDING}incoming/"
cp_pull = f"{CHECKPOINTS}autoloader/pull/requests"
cp_push = f"{CHECKPOINTS}autoloader/push/requests"

spark.sql(f"USE CATALOG {CATALOG}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1) Pull — directory listing + AvailableNow
# MAGIC Drop files with 99_simulate_arrivals.py first.

# COMMAND ----------

# TODO:
# (
#   spark.readStream.format("cloudFiles")
#     .option("cloudFiles.format", "json")
#     .option("cloudFiles.schemaLocation", f"{CHECKPOINTS}schemas/pull_requests")
#     .load(incoming)
#   ...
#   .writeStream
#   .option("checkpointLocation", cp_pull)
#   .trigger(availableNow=True)
#   .table(f"{CATALOG}.bronze.sar_requests_stream")  # or foreachBatch into bronze
# )

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2) Push — file notification mode
# MAGIC Same drops; compare latency/cost/complexity in a table for your mentor.

# COMMAND ----------

# TODO: cloudFiles.useNotifications = true
# TODO: cloudFiles.queueName / cloudFiles.storageAccount as required by your runtime docs

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3–4) Streaming Silver + Gold (foreachBatch + MERGE)
# MAGIC Quarantine failures inside the batch — do not fail the whole stream on one bad row.

# COMMAND ----------

# TODO: readStream from bronze CDF or stream table
# TODO: apply Phase 2 rules; write exceptions; MERGE gold facts

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5) Freshness measurement + 6) cost evidence
# MAGIC Capstone stretch: NRT compliance SLA view + design note.
