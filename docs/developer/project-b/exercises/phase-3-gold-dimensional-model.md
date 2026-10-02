# Phase 3: Gold dimensional model

Phase 3 of the [Project B exercises](./README.md). Prerequisite: [Phase 2 — Silver](./phase-2-silver-quality.md). Business drivers: [business-questions.md](../business-questions.md).

## Where you are

Silver clean tables exist. Analysts should not need to re-join messy operational tables for every question. You will build a **Kimball star schema** in schema `gold`.

Starter notebook: [`03_gold_star_schema.sql`](../../../../project-deployments/project-b/notebooks/03_gold_star_schema.sql) (SQL warehouse).

## Concepts first

**Dimensional modelling (Kimball):** Separate **facts** (measurable events / transactions at a declared **grain**) from **dimensions** (descriptive context). Analysts filter and group by dimensions and aggregate facts.

**Grain:** The sentence “one row in this fact means …” — write it down before coding.

**Surrogate keys vs natural keys:** Surrogate keys (`*_sk`) are warehouse-generated; natural keys (`*_id`) come from source systems. Facts usually store dimension surrogate keys (or stable natural keys if you justify the shortcut in a sandbox).

**Conformed dimensions:** Shared dims (e.g. date, officer) used by multiple facts.

**SCD (slowly changing dimensions):** How dimension attributes change over time (Type 1 overwrite, Type 2 history rows, …).

**Research further:** Kimball “bus matrix”; accumulating snapshot facts; Delta `MERGE` for incremental loads; Change Data Feed.

## Target star schema

```mermaid
erDiagram
  DIM_DATE ||--o{ FACT_SAR_REQUEST : "created_date_sk"
  DIM_OFFICER ||--o{ FACT_SAR_REQUEST : "officer_sk"
  DIM_DOCUMENT_TYPE ||--o{ FACT_SAR_REQUEST : "document_type_sk"
  DIM_STATUS ||--o{ FACT_SAR_REQUEST : "status_sk"
  DIM_DATE ||--o{ FACT_STATUS_EVENT : "changed_date_sk"
  DIM_OFFICER ||--o{ FACT_STATUS_EVENT : "changed_by_sk"
  DIM_DATE ||--o{ FACT_API_CALL : "event_date_sk"

  FACT_SAR_REQUEST {
    long request_sk PK
    string request_id NK
    long officer_sk FK
    long document_type_sk FK
    long status_sk FK
    long created_date_sk FK
    int sla_days
    bigint fulfilment_hours
  }
  FACT_STATUS_EVENT {
    long event_sk PK
    string event_id NK
    string request_id
    long changed_date_sk FK
    long changed_by_sk FK
  }
  FACT_API_CALL {
    long api_call_sk PK
    long event_date_sk FK
    string method
    string path
    int status_code
    int latency_ms
  }
  DIM_OFFICER {
    long officer_sk PK
    string officer_id NK
    string name
    string role
  }
  DIM_DOCUMENT_TYPE {
    long document_type_sk PK
    string document_type_code
  }
  DIM_DATE {
    long date_sk PK
    date calendar_date
    int year_num
    int month_num
  }
  DIM_STATUS {
    long status_sk PK
    string status_code
  }
```

Naming (enforce):

- Schemas: `gold`
- Tables: `fact_*`, `dim_*`
- Columns: `snake_case`
- Keys: `<entity>_sk`, `<entity>_id`

## Guided build

### 1. Declare grains in writing

Before SQL, write grains for:

- `fact_sar_request`
- `fact_status_event`
- `fact_api_call`

### 2. Build dimensions

Create at least:

| Table | Source | Notes |
|-------|--------|-------|
| `gold.dim_officer` | `silver.officers` | |
| `gold.dim_document_type` | distinct document types | |
| `gold.dim_status` | distinct statuses | |
| `gold.dim_date` | calendar covering your data range | Include year, month, day helpers |

Assign surrogate keys (sequences, hashes, or `row_number` — document choice).

### 3. Build facts

| Table | Measures / useful columns |
|-------|---------------------------|
| `gold.fact_sar_request` | `sla_days`, fulfilment duration when completed, flags for open/breach as you define |
| `gold.fact_status_event` | Transition attributes; link to request |
| `gold.fact_api_call` | `latency_ms`, `status_code`, `error_code`, method, path |

Join to dimensions; exclude quarantined Silver rows.

### 4. Prove with business questions

Using only Gold (+ maybe simple views), sketch SQL that would support questions 1–6 in [business-questions.md](../business-questions.md). You do not need perfect answers yet — show the joins work.

### 5. Optional incremental pattern

Enable Change Data Feed on a Silver table and demonstrate a `MERGE` into a Gold fact for a small change. Document how you would schedule it.

## Stretch challenge

1. Implement **SCD Type 2** on `dim_officer` (effective dates / current flag). Show history after a simulated role change.
2. Design (and optionally implement) an **accumulating snapshot** fact for the request lifecycle (milestones: submitted, in progress, fulfilled, …). Justify grain and update strategy to your mentor.

**Acceptance:** SCD2 demo or design note reviewed; accumulating snapshot design is coherent with Kimball terminology.

## You are done when

- [ ] Grains written and reviewed.
- [ ] Dimensions and three facts exist with naming conventions.
- [ ] At least two business questions runnable via Gold joins.
- [ ] Stretch attempted or deferred with mentor agreement.

## Questions your mentor will ask

1. What is the grain of `fact_sar_request` in one sentence?
2. Why not put `officer_name` on the fact table?
3. When would you choose SCD2 over SCD1 for officers?

---

[Exercise summary](./README.md) · Previous: [Phase 2](./phase-2-silver-quality.md) · Next: [Phase 4 — Platinum](./phase-4-platinum-business-logic.md)
