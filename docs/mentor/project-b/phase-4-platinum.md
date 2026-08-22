# Mentor — Phase 4 Platinum

Developer: [phase-4-platinum-business-logic.md](../../developer/project-b/exercises/phase-4-platinum-business-logic.md)

**Ask:** Aggregates for Q1–9; definitions; Power BI path; stretch scorecards Q10–12.

## Concepts they should explain unprompted

Serving layer; pre-aggregation trade-off; why MVs unavailable here (serverless off); freshness.

## Acceptance rubric

| Level | Looks like |
|-------|------------|
| **Strong** | Named aggs for Q1–9; written definitions; scheduled/manual refresh story; PBI connected; stretch scorecards |
| **Adequate** | Most Q1–9 covered; definitions exist; PBI blocked only on licence |
| **Not yet** | Ad-hoc queries only; no platinum schema; pointing PBI at bronze |

## Red flags

- Breach definition undefined but dashboard shows “SLA %”
- Gold wrong but platinum “looks fine” — probe lineage
- DirectQuery only with no awareness of warehouse auto-stop

## Tiered hints

1. “Write the formula for breach before SQL.”
2. “Serverless is off — what does that mean for MVs?”
3. “Try Import mode if the warehouse sleeps.”

## Model answers

1. Silver is operational/cleansed, not shaped for leadership grains.
2. Wrong gold grain → silent wrong aggregates.
3. Import often fits auto-stop warehouses better than always-on DirectQuery.

## Stretch assessment

Scorecard usability + honest freshness statement > visual polish.
