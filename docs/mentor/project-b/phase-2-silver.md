# Mentor — Phase 2 Silver

Developer: [phase-2-silver-quality.md](../../developer/project-b/exercises/phase-2-silver-quality.md)  
Key: [anomaly-map.md](../anomaly-map.md) — reveal after Layer A.

**Ask:** Discover defects; standardise; dedupe; quarantine with reason codes; reconcile.

## Concepts they should explain unprompted

Quality dimensions; quarantine vs drop; survivorship; schema drift; referential integrity.

## Acceptance rubric

| Level | Looks like |
|-------|------------|
| **Strong** | Written defect list covers most map items; exceptions tables with stable reason codes; clean silver; reconciliation arithmetic; stretch metrics/aliases |
| **Adequate** | Core defects handled (dupes, null subject, type drift, orphan officer, date parse); some map gaps OK; quarantine exists |
| **Not yet** | Silent drops; no reason codes; cleansed bronze instead; no discovery attempt |

## Expected numbers (sanity)

- Bronze requests ≈ 120 raw objects (including dupes / bad rows).
- Distinct valid request ids after trim/dedupe ≈ **118** order-of-magnitude (exact depends on rules — discuss).
- Quarantine should include (among others): null subject, `"thirty"` sla, temporal inversion, `OFF-999`, bad enums/casing if enforced, parse failures.
- Phantom FKs: events/logs may reference `SAR-2024-0011` / `SAR-2024-0012` with **no** matching request — see anomaly map.

## Red flags

- Exceptions table empty while bronze still has obvious junk
- Hard-coded only `requestor_id` ignoring `requester_id` (or vice versa) with no alias strategy
- Deduping without defining survivor

## Tiered hints

1. “Profile nulls and distinct `request_id` lengths / trim.”
2. “Look for both `requestor_id` and `requester_id`.”
3. Point to specific anomaly-map rows after they have attempted discovery.

## Model answers

1. **Duplicate vs near-duplicate** — exact key match vs keys that normalise to the same (trim/case).
2. **Orphan FK quarantine** — keep evidence; protect Gold integrity; allow repair.
3. **Enums** — map vs reject: map preserves volume, reject enforces contract; document choice.

## Stretch assessment

Metrics table that moves each run + alias resolution without a single hard-coded column name.
