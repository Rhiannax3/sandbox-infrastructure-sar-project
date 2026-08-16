# Project A — C4 modelling skeleton

Complete these diagrams before / alongside each phase. Prefer Structurizr DSL, draw.io, or Mermaid.

**Mentor / target references (end-state):**

| Level | Target diagram |
|-------|----------------|
| C1 System Context | [c1-system-context.md](./c1-system-context.md) |
| C2 Container | [c2-container.md](./c2-container.md) |
| C3 Component | [c3-component.md](./c3-component.md) |
| C4 Code | [c4-code.md](./c4-code.md) |

## Level 1 — System Context

Actors and external systems:

- Compliance Officer (person)
- SAR Compliance Portal (software system) — *provided*
- SAR Request API (software system) — *you build*
- Identity Provider / Keycloak (software system) — *provided*
- Downstream analytics / Databricks (software system) — optional narrative peer to Project B; not a runtime dependency of this sandbox

**Task:** Draw relationships (uses, authenticates with, publishes logs to). Compare with the [C1 target](./c1-system-context.md) after your first draft.

## Level 2 — Containers

For the SAR Request API system, identify containers such as:

- API Gateway
- Lambda function(s)
- DynamoDB table
- CloudWatch Logs
- JWT authorizer (Phase 3)
- (Optional) S3 for payloads

**Task:** Show how the Django portal reaches API Gateway and how auth tokens flow from Keycloak. Compare with the [C2 target](./c2-container.md).

## Level 3 — Components (Phase 2+)

Inside the Lambda container, componentise:

- HTTP router / handler
- JSON Schema validator
- Repository / DynamoDB adapter
- AuthZ scope checker (Phase 3)
- Error mapper (Phase 4)

**Task:** Update the diagram each phase; keep it honest to the code you ship. Compare with the [C3 target](./c3-component.md).

## Level 4 — Code (optional depth)

Sketch modules/classes inside the Lambda components (handler, routes, validation, repository, errors). Compare with the [C4 target](./c4-code.md) — names may differ; structure should rhyme.

## Deliverable

Work the phases in [SAR request exercises](./sar_request_exercises.md). Submit Context + Container diagrams after Phase 1, an updated Component diagram after Phase 2, and optionally a Code sketch when your mentor asks for implementation detail.
