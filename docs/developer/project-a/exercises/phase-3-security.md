# Phase 3: Security & Identity

Phase 3 of the [SAR request exercises](./phased-exercises.md). Keycloak roles, clients, and scopes are described in the [realm notes](../../../../app/keycloak/README.md).

## Theory and context

Right now, anyone on the internet with your API URL could create a SAR request. We need to secure it using **Zero Trust** architecture.

When an officer logs into Keycloak, they receive a JSON Web Token (JWT) — a digital ID badge. It contains **scopes** (what they are allowed to do, like `sar:read` or `sar:approve`). Your API Gateway needs an **authorizer** that checks this badge *before* the request reaches Lambda.

## Your goals

1. Research OAuth 2.0 / OIDC and JWT claims: Issuer (`iss`), Audience (`aud`), expiry (`exp`), scopes.
2. Configure an API Gateway JWT authorizer (or Lambda authorizer) against:
  - Issuer `https://<hostname>/auth/realms/sar-sandbox`
  - Audience `sar-api`
3. Map scopes to operations, for example:
  - `sar:read` — list / get
  - `sar:write` — create / update / delete
  - `sar:approve` — senior-only transitions (e.g. approve / reject) if you model them
4. Demonstrate `officer.standard` cannot do senior-only actions; `officer.senior` can.
5. Ask your mentor to set `SAR_API_AUTH_ENABLED=true` on the host so the portal sends Bearer tokens; retest while logged in.
6. Confirm anonymous `curl` without a token gets **401/403**.

Do not reconfigure Keycloak clients unless your mentor agrees — the realm already defines `sar-api` and the scopes.

## You are done when

- [ ] Unauthenticated API calls fail.
- [ ] Authenticated portal flows still work with JWT mode on.
- [ ] Scope differences between standard and senior are demonstrable.
- [ ] Short write-up: which claims you trust and why.

---

[Exercise summary](./phased-exercises.md) · Previous: [Phase 2 — Core API & Dynamic State](./phase-2-core-api.md) · Next: [Phase 4 — Resilience & Error Handling](./phase-4-resilience.md)
