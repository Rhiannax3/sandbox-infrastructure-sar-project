# Mentor only — Seed data anomaly map

Maps deliberate defects in `seed-data/out` to teaching points. **Do not share with juniors until after they have attempted discovery** (typically after Phase 2 Layer A).

| Anomaly | Where | Rows / files | Surfaces in | Silver / later challenge | Reveal timing |
|---------|-------|--------------|-------------|--------------------------|---------------|
| Exact duplicate `request_id` | `sar_requests/requests_2024.json` | `SAR-2024-0010` appears twice (i=10 and i=11) | Phase 2 | Deduplicate by natural key; define survivor rules | After their defect list |
| Near-duplicate ID (trailing space) | same | i=12 `SAR-2024-0010 ` | Phase 2 | Trim/normalise identifiers before dedupe | After their defect list |
| Null mandatory `subject_id` | same | i=20 | Phase 2 | Quarantine null violations | After their defect list |
| Enum casing drift (`HIGH`, `In_Progress`) | same | i=21, i=22 | Phase 2 | Case-normalise or quarantine unknown enums | After their defect list |
| Mixed date formats | same | i=30 `%Y-%m-%d`; i=31 `%d/%m/%Y %H:%M` | Phase 2 | Multi-format parse; quarantine unparseable | After their defect list |
| Type drift on `sla_days` | same | i=40 `"thirty"` | Phase 2 | Cast with quarantine on failure | After their defect list |
| `completed_at` before `created_at` | same | i=50 | Phase 2 | Temporal sanity check → quarantine | After their defect list |
| Orphan `requestor_id` | same | i=60 `OFF-999` | Phase 2–3 | Referential integrity vs `reference/officers.csv` | After their defect list |
| Schema drift rename | same | i≥80 `requestor_id` → `requester_id` | Phase 2, **Phase 6** | Schema evolution / column aliasing; mid-stream drift | After discovery; revisit in Phase 6 |
| Latin-1 flavoured name fields | same | i=90 | Phase 2 | Encoding handling | Optional depth |
| Truncated JSON file | `requests_2024_tail_truncated.json` | whole file | Phase 1 stretch, Phase 2 | Corrupt file quarantine; don't fail whole load | Phase 1 stretch / Phase 2 |
| Duplicate status event | `events/status_events.csv` | copy of first event | Phase 2 | Event-level dedupe | After their defect list |
| Empty `changed_by` | same | `EVT-NULL-ACTOR` | Phase 2 | Null actor handling | After their defect list |
| Null/empty `request_id` in logs | `logs/api_access.jsonl` | random choices include `None`/`""` | Phase 2–3 | Optional FK; don't drop metrics | After their defect list |
| Mixed log timestamp | same | index 3 `dd-mm-YYYY` | Phase 2 | Align to UTC timestamp type | After their defect list |
| **Phantom request IDs** | events + logs | `SAR-2024-0011`, `SAR-2024-0012` referenced but **no** matching request row (generator overwrote those ids with duplicate `SAR-2024-0010`) | Phase 2–3 | Orphan FK from events/logs → requests; do not invent requests to “fix” joins | Reveal if they notice orphan events; otherwise after Gold RI discussion |

## Suggested mentoring flow

1. Ask engineers to profile Bronze and list quality issues they observe.
2. Compare their list to this map — reward discovery, then reveal gaps.
3. Require an `*_exceptions` / quarantine table with reason codes matching the rows above.
4. In Phase 6, ask how the same alias/schema-drift issues would be handled **mid-stream** without failing the pipeline.
