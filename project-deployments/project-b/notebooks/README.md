# Project B — starter notebooks

Databricks **source format** notebooks (`.py` / `.sql`) for the [guided exercises](../../docs/developer/project-b/exercises/README.md).

| File | Phase |
|------|-------|
| `00_setup_check.py` | Preflight |
| `01_bronze_ingest.py` | 1 |
| `02_silver_cleanse_quarantine.py` | 2 |
| `03_gold_star_schema.sql` | 3 |
| `04_platinum_business_logic.sql` | 4 |
| `05_governance_grants.sql` | 5 |
| `06_streaming_nrt.py` | 6 |
| `99_simulate_arrivals.py` | 1 stretch / 6 |

These are **scaffolds with TODOs**, not solutions.

## Import into the workspace

### Option A — Git folder (preferred)

Add this repo as a Databricks Git folder and open `project-deployments/project-b/notebooks/`.

### Option B — CLI

```bash
# From repo root; DATABRICKS_HOST + azure-cli auth
databricks workspace import-dir \
  project-deployments/project-b/notebooks \
  /Users/<your-email>/project-b-notebooks \
  --overwrite
```

Or: `make b-notebooks ENGINEER=<id>` (imports to `/Shared/sar-<id>/notebooks`).

## Before you run

1. Create a cluster **using the cost-capped policy** only.
2. Replace `sar_sandbox_<you>` and storage account placeholders from `terraform output`.
3. Run `00_setup_check.py` first.
