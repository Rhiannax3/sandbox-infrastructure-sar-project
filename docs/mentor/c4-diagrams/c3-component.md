# Project A — Target C3 (Component)

**Audience:** mentors / reference for juniors (Phase 2+).  
**Zoom:** inside the **Lambda** container of the SAR Request API.

C3 shows **components** (major code modules / responsibilities) — not every file or function (that is C4).

```mermaid
flowchart TB
  apigw["External — API Gateway<br/><i>Invokes Lambda with event</i>"]
  ddb["External — DynamoDB<br/><i>Request items</i>"]
  authorizer["External — JWT authorizer<br/><i>Phase 3 gate before Lambda</i>"]

  subgraph lambda ["Lambda — SAR Request API"]
    router["Component<br/>HTTP router / handler<br/><i>Maps method and path to use cases</i>"]
    validator["Component<br/>JSON Schema validator<br/><i>Envelope plus payload by document_type</i>"]
    authz["Component — Phase 3<br/>Scope checker<br/><i>sar:read write approve</i>"]
    repo["Component<br/>Repository / DynamoDB adapter<br/><i>CRUD persistence</i>"]
    errors["Component — Phase 4<br/>Error mapper<br/><i>Exceptions to HTTP status and JSON body</i>"]
  end

  contracts["External — project-deployments/project-a/lambda/contracts/<br/><i>Shared JSON Schemas</i>"]

  apigw --> router
  authorizer -.->|"Already enforced at edge"| router
  router --> authz
  router --> validator
  validator -->|"Loads schemas"| contracts
  authz -->|"Allows or rejects by scope"| router
  router --> repo
  repo --> ddb
  router --> errors
  validator --> errors
  repo --> errors
  authz --> errors
  errors -->|"StatusCode and body on response"| apigw
```

## Component responsibilities

| Component | Phase | Responsibility |
|-----------|-------|----------------|
| HTTP router / handler | 1–2 | Dispatch `GET /health`, `/requests`, `/requests/{id}` |
| JSON Schema validator | 2 | Envelope + payload schema for `document_type` |
| Repository | 2 | DynamoDB read/write; one requests table |
| Scope checker | 3 | Enforce `sar:read` / `sar:write` / `sar:approve` (if not fully pushed into the Gateway authorizer) |
| Error mapper | 4 | Map domain/infra failures to stable HTTP codes and JSON errors |

## Boundary reminder

- Authorizer may sit **in API Gateway** (C2). If so, the Lambda scope checker is thin or only handles fine-grained rules — say so on your own diagram.  
- Do not redraw Portal/Keycloak internals here.  
- **Next level:** illustrative code modules on [C4](./c4-code.md).
