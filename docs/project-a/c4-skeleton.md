# Project A — C4 modelling skeleton

Complete these diagrams before / alongside each phase. Prefer Structurizr DSL, draw.io, or Mermaid.

## Level 1 — System Context

Actors and external systems:

- Compliance Officer (person)
- SAR Compliance Portal (software system) — *provided*
- SAR Request API (software system) — *you build*
- Identity Provider / Keycloak (software system) — *provided*
- Downstream analytics / Databricks (software system) — Project B

**Task:** Draw relationships (uses, authenticates with, publishes logs to).

## Level 2 — Containers

For the SAR Request API system, identify containers such as:

- API Gateway
- Lambda function(s)
- DynamoDB table
- CloudWatch Logs
- (Optional) S3 for payloads

**Task:** Show how the Django portal reaches API Gateway and how auth tokens flow from Keycloak.

## Level 3 — Components (Phase 2+)

Inside the Lambda container, componentise:

- HTTP router / handler
- JSON Schema validator
- Repository / DynamoDB adapter
- AuthZ scope checker (Phase 3)
- Error mapper (Phase 4)

**Task:** Update the diagram each phase; keep it honest to the code you ship.

## Deliverable

Submit Context + Container diagrams after Phase 1, and an updated Component diagram after Phase 2.
