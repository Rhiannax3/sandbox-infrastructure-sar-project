# Phase 4: Resilience & Error Handling

Phase 4 of the [SAR request exercises](./phased-exercises.md). The final phase; finish with your C4 diagrams matching what you shipped.

## Theory and context

In cloud engineering, things *will* break. Databases time out, networks drop. Professional APIs fail gracefully. Instead of a blank screen, your API must catch errors and return standard HTTP status codes (e.g. 404 Not Found, 500 Internal Error, 503 Service Unavailable) so the frontend can show a polite message.

## Your goals

1. Introduce at least two controlled failure scenarios (examples: wrong DynamoDB table name, forced timeout, not-found vs validation vs conflict).
2. Catch exceptions and return clean JSON errors like `{"error":"...","code":"..."}` with the correct HTTP status (400 / 401 / 403 / 404 / 409 / 500 / 503 as appropriate). Log failures with the provided `logging_helpers.logger` so CloudWatch shows the cause without dumping a stack into the HTTP body.
3. Verify the portal shows a useful `SarApiError` / message instead of an opaque crash where you control the API.
4. **Theory exercise:** Write a short paper (length defined by mentor) on **AWS Lambda intra-region availability**: what AWS provides out of the box, what you still design for (retries, idempotency, multi-AZ data), and what this sandbox does *not* prove (e.g. multi-region active-active).

## You are done when

- [ ] Failure scenarios demoed with expected status codes.
- [ ] Portal shows understandable errors for those cases.
- [ ] Availability write-up submitted.
- [ ] C4 diagrams still match what you shipped.

---

[Exercise summary](./phased-exercises.md) · Previous: [Phase 3 — Security & Identity](./phase-3-security.md)
