# Project B — Business questions

These questions drive Gold (dimensional) and Platinum (aggregated) design. Answer them with data products, not ad-hoc notebooks.

## Operational SLAs

1. What is the **average fulfilment time** (submitted → fulfilled) by document type and by priority?
2. What percentage of requests **breach the SLA** (`sla_days`) each month?
3. How does fulfilment time differ between **standard** and **senior** officers?

## Officer engagement

4. How many requests does each officer **open** vs **close** per week?
5. Which officers have the highest rate of **rejected** or **cancelled** requests?
6. What is the mix of document types handled by each officer role?

## System resilience

7. What is the API **error rate** (4xx/5xx) by day and by route?
8. Which error codes correlate with spikes in request backlog?
9. What is the p95 **latency** for `POST /requests` vs `GET /requests`?

## Compliance leadership views (Platinum)

10. Executive scorecard: SLA attainment %, open backlog, median fulfilment time — current month vs prior month.
11. Heatmap: document type × priority → breach rate.
12. Reliability scorecard: error rate and timeout rate alongside backlog size.

## Modelling notes

- Gold should let analysts slice facts by date, officer, document type, priority, and status without recomputing joins.
- Platinum should pre-compute the scorecard grains above for Power BI.
