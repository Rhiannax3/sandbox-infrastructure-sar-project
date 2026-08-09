# Mentor only — Seed data anomaly map

Maps deliberate defects in `seed-data/out` to Silver-layer teaching points. **Do not share with juniors until after they have attempted discovery.**

| Anomaly | Where | Rows / files | Silver challenge |
|---------|-------|--------------|------------------|
| Exact duplicate `request_id` | `sar_requests/requests_2024.json` | `SAR-2024-0010` appears twice (i=10 and i=11) | Deduplicate by natural key; define survivor rules |
| Near-duplicate ID (trailing space) | same | i=12 `SAR-2024-0010 ` | Trim/normalise identifiers before dedupe |
| Null mandatory `subject_id` | same | i=20 | Quarantine null violations |
| Enum casing drift (`HIGH`, `In_Progress`) | same | i=21, i=22 | Case-normalise or quarantine unknown enums |
| Mixed date formats | same | i=30 `%Y-%m-%d`; i=31 `%d/%m/%Y %H:%M` | Multi-format parse; quarantine unparseable |
| Type drift on `sla_days` | same | i=40 `"thirty"` | Cast with quarantine on failure |
| `completed_at` before `created_at` | same | i=50 | Temporal sanity check → quarantine |
| Orphan `requestor_id` | same | i=60 `OFF-999` | Referential integrity vs `reference/officers.csv` |
| Schema drift rename | same | i≥80 `requestor_id` → `requester_id` | Schema evolution / column aliasing |
| Latin-1 flavoured name fields | same | i=90 | Encoding handling |
| Truncated JSON file | `requests_2024_tail_truncated.json` | whole file | Corrupt file quarantine; don't fail whole load |
| Duplicate status event | `events/status_events.csv` | copy of first event | Event-level dedupe |
| Empty `changed_by` | same | `EVT-NULL-ACTOR` | Null actor handling |
| Null/empty `request_id` in logs | `logs/api_access.jsonl` | random choices include `None`/`""` | Optional FK; don't drop metrics |
| Mixed log timestamp | same | index 3 `dd-mm-YYYY` | Align to UTC timestamp type |

## Suggested mentoring flow

1. Ask engineers to profile Bronze and list quality issues they observe.
2. Compare their list to this map — reward discovery, then reveal gaps.
3. Require an `*_exceptions` / quarantine table with reason codes matching the rows above.
