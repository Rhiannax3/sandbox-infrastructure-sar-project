# Phase 4: Platinum business logic

Phase 4 of the [Project B exercises](./README.md). Prerequisite: [Phase 3 — Gold](./phase-3-gold-dimensional-model.md). Drivers: [business-questions.md](../business-questions.md). Connectivity: [power-bi.md](../power-bi.md).

## Where you are

Gold star schema exists. Leadership still should not run heavy ad-hoc joins for every dashboard refresh. **Platinum** is the serving layer: pre-aggregated **data products** shaped for known questions.

Starter notebook: [`04_platinum_business_logic.sql`](../../../../project-deployments/project-b/notebooks/04_platinum_business_logic.sql).

## Concepts first

**Serving layer:** Tables (or views) optimised for consumption — stable names, documented grains, refresh cadence.

**Pre-aggregation trade-offs:** Faster dashboards and simpler BI models vs less flexibility and more pipelines to maintain.

**Materialisation:** In this sandbox, **serverless is off**, so Databricks SQL **materialized views / streaming tables are not available**. Use Delta tables refreshed by notebooks or Jobs (scheduled). Say this explicitly in your design notes so it does not look like an arbitrary choice.

**Research further:** Semantic models in Power BI; star schema vs flat aggregates; SLA for data freshness.

## Guided build

Create schema `platinum`. Build aggregates that answer questions **1–9** in [business-questions.md](../business-questions.md). Suggested table shapes (adjust names with mentor agreement):

| Table | Supports questions | Example grain |
|-------|--------------------|---------------|
| `platinum.agg_fulfilment_by_type_priority` | 1 | document_type × priority |
| `platinum.agg_sla_breach_monthly` | 2 | year-month |
| `platinum.agg_fulfilment_by_officer_role` | 3 | role |
| `platinum.agg_officer_open_close_weekly` | 4 | officer × week |
| `platinum.agg_officer_reject_cancel_rate` | 5 | officer |
| `platinum.agg_doc_type_by_officer_role` | 6 | role × document_type |
| `platinum.agg_api_error_rate_daily` | 7 | day × route |
| `platinum.agg_error_vs_backlog` | 8 | day (or week) |
| `platinum.agg_api_latency_percentiles` | 9 | method / path |

Define **breach**, **fulfilment time**, and **backlog** in writing before coding (e.g. open = not in terminal statuses; breach = fulfilment hours > `sla_days * 24`).

Refresh pattern: a Job or notebook that rebuilds Platinum from Gold on a schedule you choose (even if you only run it manually in the sandbox).

### Connect Power BI

Follow [power-bi.md](../power-bi.md). Import or DirectQuery against Platinum (and optionally Gold). Note warehouse cold-start after auto-stop.

## Stretch challenge

1. Implement leadership scorecards for questions **10–12** (executive scorecard, heatmap grain, reliability scorecard).
2. Publish a simple Power BI dashboard with those visuals.
3. Document refresh approach and freshness expectation.

**Acceptance:** Mentor can open the dashboard (or screenshots + measures) and see scorecards populated from Platinum.

## You are done when

- [ ] Schema `platinum` with aggregates covering Q1–9.
- [ ] Definitions of fulfilment, breach, backlog written down.
- [ ] Power BI connected (or blocked only by licence — escalate to mentor).
- [ ] Stretch attempted or deferred with mentor agreement.

## Questions your mentor will ask

1. Why not point Power BI only at Silver?
2. What breaks if Gold grain is wrong but Platinum looks “fine”?
3. Import vs DirectQuery — which fits this sandbox’s warehouse auto-stop behaviour?

---

[Exercise summary](./README.md) · Previous: [Phase 3](./phase-3-gold-dimensional-model.md) · Next: [Phase 5 — Governance](./phase-5-governance-rbac.md)
