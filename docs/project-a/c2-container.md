# Project A — Target C2 (Container)

**Audience:** mentors / reference for juniors.  
**Zoom:** inside the **SAR Request API** software system (engineer-built), with adjacent provided systems shown as externals.

C2 shows **containers** (deployable/runnable units) — not classes or Lambda-internal modules (those are C3).

```mermaid
flowchart TB
  portal["External container — provided<br/>SAR Compliance Portal<br/><i>Django on sandbox host</i>"]
  idp["External container — provided<br/>Keycloak<br/><i>OIDC and JWT issuer</i>"]
  ssm["External — AWS SSM<br/>api-base-url parameter<br/><i>Portal discovers API base URL</i>"]

  subgraph sarApi ["SAR Request API — engineer builds"]
    apigw["Container<br/>API Gateway<br/><i>HTTP routes HTTP API or REST stage</i>"]
    authorizer["Container — Phase 3<br/>JWT authorizer<br/><i>Validates iss aud scopes</i>"]
    lambda["Container<br/>Lambda function(s)<br/><i>Business logic</i>"]
    ddb["Container<br/>DynamoDB<br/><i>sar-engineer-requests table</i>"]
    cwl["Container<br/>CloudWatch Logs<br/><i>Function and access logs</i>"]
  end

  portal -->|"Reads base URL"| ssm
  portal -->|"HTTPS CRUD and health<br/>Bearer JWT from Phase 3"| apigw
  apigw --> authorizer
  authorizer -->|"Allows or denies"| lambda
  apigw -->|"Phase 1 to 2 open or IAM none"| lambda
  lambda -->|"GetItem PutItem Query"| ddb
  lambda -->|"Writes logs"| cwl
  authorizer -->|"JWKS / JWT validation"| idp
  portal -->|"OIDC login"| idp
```

## Relationship notes

| From → To | Meaning |
|-----------|---------|
| Portal → SSM | Discovers invoke base URL (`/sar-sandbox/<id>/api-base-url`) |
| Portal → API Gateway | All live traffic; include REST **stage** in base URL if using REST API |
| API Gateway → Authorizer → Lambda | Phase 3 path; before Phase 3, Gateway may invoke Lambda with auth `NONE` on routes |
| Lambda → DynamoDB | Persist SAR request envelopes (one table; `document_type` in item) |
| Lambda → CloudWatch | Operational logs; optional narrative feed to analytics on C1 |
| Authorizer → Keycloak | Trust issuer `…/auth/realms/sar-sandbox`, audience `sar-api` |

## Boundary reminder

- **In this diagram’s boundary:** API Gateway, authorizer, Lambda, DynamoDB, CloudWatch.  
- **Outside (provided):** Portal, Keycloak, SSM.  
- **Optional / not required:** dedicated S3 for payloads.  
- **Next level:** zoom into Lambda on [C3](./c3-component.md).
