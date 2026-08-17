# Project A — SAR request exercises

Phased delivery plan for the AWS API & Document Request System. Read the environment and integration seams in the [engineer runbook](../runbook.md) first, then work these phases with your mentor.

Four phases take you from an empty AWS account to a secured, resilient API that the SAR Compliance Portal uses as its live backend. Each phase builds on the last, so work them in order. Each phase has its own page:

| Phase | Focus | What you build | Concepts and services | Done signal |
|-------|-------|----------------|-----------------------|-------------|
| **[1 — Foundation & The C4 Model](./phase-1-foundation.md)** | Plan the architecture, then prove one path end to end | Hello-world Lambda, API Gateway `GET /health`, SSM base URL | C4 modelling, serverless, API Gateway, SSM parameters | Context + Container diagrams reviewed; portal header shows `API: live` |
| **[2 — Core API & Dynamic State](./phase-2-core-api.md)** | Turn one route into a validated, persistent CRUD API | Full `/requests` routes, JSON Schema validation, DynamoDB table, repository | REST semantics, JSON Schema contracts, DynamoDB access patterns | Full CRUD through the portal for multiple document types; C3 diagram updated |
| **[3 — Security & Identity](./phase-3-security.md)** | Stop anonymous access and enforce what each officer may do | API Gateway JWT authorizer, scope-to-operation mapping | OAuth 2.0 / OIDC, JWT claims, Keycloak scopes | Anonymous calls fail; standard vs senior difference demonstrable |
| **[4 — Resilience & Error Handling](./phase-4-resilience.md)** | Fail predictably and observably instead of crashing | Error mapper, controlled failure scenarios, CloudWatch logging | HTTP status semantics, retries and idempotency, availability design | Failure scenarios demoed; portal shows useful errors; availability write-up submitted |

## How to work the phases

- **Follow the order.** Phase 2 assumes the Phase 1 `GET /health` path still works; Phase 3 secures the routes Phase 2 creates.
- **Treat each checklist as a checkpoint.** The **You are done when** list that closes a phase page is what you walk through with your mentor before moving on.
- **Phase 2 is the largest.** It is split into Layers A–E (API surface, validation, DynamoDB model, repository wiring, portal proof), each with its own exit criteria — do one layer at a time rather than the whole phase at once.
- **Keep the diagrams current.** Phase 1 produces Context and Container diagrams in the [C4 skeleton](../c4-skeleton.md); Phase 2 adds the Component view; Phase 4 closes by checking the diagrams still match what you shipped.

## Reference material

| Doc | Use |
|-----|-----|
| [Engineer runbook](../runbook.md) | Environment, integration seams, portal paths, getting-started checklist |
| [C4 modelling skeleton](../c4-skeleton.md) | What to draw at each level and why |
| [`project-deployments/project-a/lambda/contracts/`](../../../../project-deployments/project-a/lambda/contracts/) | JSON Schema contracts shared with the portal |
| [Lambda deploy folder](../../../../project-deployments/project-a/README.md) | Edit and publish your function code |
