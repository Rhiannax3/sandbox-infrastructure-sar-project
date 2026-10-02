# Databricks notebook source
# MAGIC %md
# MAGIC # 99 — Simulate arrivals
# MAGIC
# MAGIC Copies (or writes) **new file paths** under `landing/incoming/batch=<timestamp>/`
# MAGIC so Auto Loader can see genuinely new paths (static `raw/` overwrites are not enough).
# MAGIC
# MAGIC Requires WRITE_FILES on the landing external location (data-engineers).

# COMMAND ----------

from datetime import datetime, timezone
import json

LANDING = "abfss://landing@<storage_account>.dfs.core.windows.net/"
RAW = f"{LANDING}raw/sar_requests/requests_2024.json"
BATCH = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
DEST_DIR = f"{LANDING}incoming/batch={BATCH}/"
DEST_FILE = f"{DEST_DIR}requests_slice.json"

print("Destination:", DEST_FILE)

# COMMAND ----------

# Option A — copy whole seed file to a new path (simple Auto Loader demo)
dbutils.fs.mkdirs(DEST_DIR)
dbutils.fs.cp(RAW, DEST_FILE)
print("Copied seed requests JSON to", DEST_FILE)

# COMMAND ----------

# Option B (optional) — write a tiny JSON array of synthetic rows
# synthetic = [
#     {
#         "request_id": f"SAR-SIM-{BATCH}-001",
#         "document_type": "user_profile_summary",
#         "requestor_id": "OFF-001",
#         "subject_id": "SUBJ-99999",
#         "priority": "medium",
#         "status": "submitted",
#         "sla_days": 14,
#         "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S"),
#         "completed_at": None,
#         "channel": "portal",
#     }
# ]
# dbutils.fs.put(f"{DEST_DIR}synthetic.json", json.dumps(synthetic), overwrite=True)

# COMMAND ----------

display(dbutils.fs.ls(DEST_DIR))
