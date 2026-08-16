# Project A — Target C4 (Code)

**Audience:** mentors / reference for juniors (optional depth).  
**Zoom:** illustrative **code elements** inside the Lambda components. Keep this light — C4 is a sketch of modules, not a full class browser.

C4 shows **classes / modules / packages** that implement C3 components. Juniors’ real names may differ; the shape should match.

```mermaid
flowchart TB
  subgraph router ["Component: HTTP router"]
    handler["handler.py / lambda_handler<br/><i>Entrypoint parses API Gateway event</i>"]
    routes["routes.py<br/><i>Path and method table</i>"]
  end

  subgraph validator ["Component: JSON Schema validator"]
    schema_loader["schemas.py<br/><i>Load contracts from package or layer</i>"]
    validate_fn["validate_request.py<br/><i>Envelope then payload by document_type</i>"]
  end

  subgraph authz ["Component: Scope checker"]
    claims["claims.py<br/><i>Read scopes from authorizer context or JWT</i>"]
    require_scope["require_scope.py<br/><i>Guard write and approve operations</i>"]
  end

  subgraph repo ["Component: Repository"]
    model["models.py<br/><i>Request document shape</i>"]
    ddb_repo["dynamodb_repository.py<br/><i>Get Put Delete Query</i>"]
  end

  subgraph errors ["Component: Error mapper"]
    exc["errors.py<br/><i>Domain exception types</i>"]
    map_http["http_errors.py<br/><i>Map to status and JSON body</i>"]
  end

  handler --> routes
  routes --> require_scope
  routes --> validate_fn
  routes --> ddb_repo
  require_scope --> claims
  validate_fn --> schema_loader
  ddb_repo --> model
  routes --> map_http
  validate_fn --> exc
  ddb_repo --> exc
  require_scope --> exc
  exc --> map_http
```

## Notes for reviewers

- File names are **examples** — accept equivalent structure in the junior’s repo.  
- Prefer one deployable Lambda (or a small set) over a large microservice farm for this sandbox.  
- Contracts come from [`project-deployments/project-a/lambda/contracts/`](../../project-deployments/project-a/lambda/contracts/) — they ship in the function zip; do not silently diverge from the portal.
- CloudWatch logging uses the provided [`logging_helpers.py`](../../project-deployments/project-a/lambda/logging_helpers.py) (`log_event`, `logger`); prefer that over ad-hoc `print`.  
- **Zoom back out:** [C3](./c3-component.md) · [C2](./c2-container.md) · [C1](./c1-system-context.md)
