# Mentor — Phase 1 Bronze

Developer: [phase-1-bronze-ingestion.md](../../developer/project-b/exercises/phase-1-bronze-ingestion.md)

**Ask:** Append-only Bronze tables with audit columns; prove idempotency; optional Auto Loader stretch.

## Concepts they should explain unprompted

Medallion / Bronze role; append-only vs cleanse; idempotency; why audit columns; Auto Loader path-based dedupe (stretch).

## Acceptance rubric

| Level | Looks like |
|-------|------------|
| **Strong** | Four bronze tables; audit cols; second run does not double; clear write-up of mechanism; micro-batches demoed; stretch with new `incoming/` paths |
| **Adequate** | Tables + audit cols; idempotency fixed (even if only overwrite); thin write-up; stretch deferred with agreement |
| **Not yet** | Cleansing in Bronze; doubled rows ignored; no audit cols; “incremental” proven only by re-reading same `raw/` path |

## Expected numbers (static seed)

| Source | Approx |
|--------|--------|
| Requests JSON objects | 120 |
| Status events | 102 |
| API logs | 200 |
| Officers | 4 |

Corrupt file should not appear as a clean 120th+ successful parse without an explicit quarantine/skip story.

## Red flags

- Nulls dropped / enums fixed in Bronze
- No `_source_file` / `_ingested_at` / `_batch_id`
- Claiming Auto Loader works after only re-running on unchanged `raw/` paths

## Tiered hints

1. “What happens if you append the same file twice?”
2. “Auto Loader keys off file **path** — same path, new bytes?”
3. “Use `99_simulate_arrivals.py` under `incoming/batch=…/` and checkpoint under the checkpoints location.”

## Model answers (mentor questions)

1. **Keep bad data in Bronze** — preserve source truth and lineage; cleansing is Silver’s job; debuggability.
2. **Auto Loader processed set** — path (and notification) tracking in the checkpoint location.
3. **Overwrite same path** — generally **will not** re-ingest; path already seen.

## Stretch assessment

Prefer a working notification/listing demo with **new paths** over a perfect continuous stream. Design clarity > clever API use.
