# Phase 2: Core API & Dynamic State

Phase 2 of the [SAR request exercises](./phased-exercises.md). This is the largest phase, split into Layers A–E that each end with their own exit criteria.

## Theory and context

RESTful APIs use standard HTTP methods (`POST` to create, `GET` to read, `PUT` to update, `DELETE` to remove) to manage resources.

AWS Lambda is **stateless** — when an invocation finishes, in-memory state is gone. Persistent SAR requests need an external store: **DynamoDB**.

Bad input should fail fast. **JSON Schema contracts** in [`project-deployments/project-a/lambda/contracts/`](../../../../project-deployments/project-a/lambda/contracts/) define the envelope and per–document-type payloads. Validate before you write.

Work this phase **one layer at a time**. At each layer, pause on the design decisions, note your choice for your mentor, then implement. Update your **C3 Component** diagram as the pieces appear (router → validator → repository).

## One resource, three document types

**Shared rule for all layers:** there is **one** business resource — a **SAR request**. The three document types are `document_type` values on the same envelope; they change **payload validation**, not which URL family or table you must create.

```json
{
  "request_id": "…",
  "document_type": "user_consent_log",
  "subject": { },
  "requestor": { },
  "priority": "Medium",
  "status": "Submitted",
  "created_at": "…",
  "payload": { }
}
```

---

## Layer A — API surface (resource design)

### Goal

Expand API Gateway + Lambda so the portal’s live client can call the paths in [runbook §4.2](../runbook.md#42-paths-the-portal-expects). Keep `GET /health` working.

### Paths the portal expects

| Method   | Path             | Portal use            |
| -------- | ---------------- | --------------------- |
| `GET`    | `/health`        | Home page health line |
| `GET`    | `/requests`      | List                  |
| `GET`    | `/requests/{id}` | Detail                |
| `POST`   | `/requests`      | Create                |
| `PUT`    | `/requests/{id}` | Update                |
| `DELETE` | `/requests/{id}` | Delete                |

### Design decisions to consider

1. **One resource vs three** — Prefer `/requests` for all document types. Separate `/user-profile-summaries` APIs fight the portal client and duplicate CRUD. Justify any divergence with your mentor first.
2. **REST vs HTTP API** — You may already have one from Phase 1. Stay consistent; remember REST base URLs in SSM must include the **stage**.
3. **One Lambda vs many** — A single function with an internal router is enough for this sandbox. Multiple functions are fine if you have a clear reason (blast radius, scaling) and still match the portal paths.
4. **IDs** — Who mints `request_id`? Portal/mock often expects a UUID on create. Prefer server-generated UUID on `POST` and return it in the body; reject client IDs that collide if you allow them.
5. **List semantics** — Unfiltered `GET /requests` is enough for Phase 2. Will you later filter by status, officer, or document type? That choice feeds Layer C (keys / GSIs).
6. **Idempotency & PUT** — Is `PUT` full replace of the envelope + payload, or partial patch? Full replace is simpler; document it. What happens on unknown `id`? (`404`)
7. **Status values** — Align with the envelope enum (`Draft`, `Submitted`, `In Progress`, `Pending Approval`, `Fulfilled`, `Rejected`, `Cancelled`). Which values can a standard officer set vs leave for Phase 3 approve flows?

### Exit Layer A when

`curl` can hit each route (even if persistence is still in-memory or stubbed) and responses use JSON.

---

## Layer B — Validation (contracts)

### Goal

On `POST`/`PUT`, validate **before** DynamoDB writes.

1. Validate the **envelope** against `sar-request-envelope.schema.json`.
2. Read `document_type` and validate `payload` against the matching `user-*.schema.json`.
3. Unknown `document_type` or schema failure → **4xx** with a clear body (not a 500 stack trace).

### Sharing the data contracts with your Lambda

Write your function in [`project-deployments/project-a/lambda/`](../../../../project-deployments/project-a/README.md). Schemas already sit next to the handler at `lambda/contracts/` (the same files the portal mounts). Publish that folder — do not keep a second, divergent copy of the schemas.

```text
project-deployments/project-a/lambda/
  example_lambda_function.py  # template — copy to lambda_function.py
  lambda_function.py          # handler: lambda_function.lambda_handler (gitignored)
  validate.py                 # provided — envelope + payload schema checks
  logging_helpers.py          # provided — CloudWatch logger (log_event / logger)
  requirements.txt
  publish.sh
  contracts/
    sar-request-envelope.schema.json
    user-profile-summary.schema.json
    user-activity-report.schema.json
    user-consent-log.schema.json
```

1. Copy `example_lambda_function.py` to `lambda_function.py` and replace the stub. Import the provided `validate.py` (`from validate import parse_body, validate_request, ContractError`) and `logging_helpers.py` (`from logging_helpers import log_event, logger`). Add other sibling modules as needed; parent-directory imports do not work. Call `log_event(event)` at the start of the handler so CloudWatch shows the API Gateway payload (method, resource, `pathParameters`) rather than an empty or unstructured line.
2. Enrich POST bodies with `request_id` / `created_at` / `status`, then `validate_request` (payload schema by `document_type`, then the envelope). Invalid bodies → 4xx via `ContractError.to_response()`.
3. From a laptop with the AWS CLI (`tar` is enough; you do **not** need local Python/`pip`):

```bash
cd project-deployments/project-a/lambda
ENGINEER_ID=<you> ./publish.sh sar-<you>-lambda          # optional second arg: region (default eu-west-2)
```

The script ships source to your sandbox host, which installs `requirements.txt` and runs `update-function-code`. Full steps: [`project-deployments/project-a/README.md`](../../../../project-deployments/project-a/README.md).

**Schema changes:** edit `lambda/contracts/` once, then publish again so the zip matches the portal. Do not invent inline Python dicts as a second source of truth.

### Other packaging options

| Approach | How | Pros | Cons / when |
|----------|-----|------|-------------|
| **Zip from `project-deployments/project-a/lambda/`** (above) | Schemas already inside the package | Simple; no extra IAM; versioned with the function | Must republish to pick up schema edits |
| **Lambda layer** | Publish a layer with `/contracts` (or `python/contracts`) and attach it; read from `/opt/...` | Share across several functions; smaller function zips | Extra publish step; still update the layer version on schema change |
| **S3 object(s)** | Upload `contracts/` to e.g. `s3://sar-<you>-artifacts-…/contracts/`; Lambda `GetObject` on cold start and cache | Update schemas without a code deploy | Needs IAM + bucket; cache invalidation; more moving parts than this phase needs |

For Project A, prefer the zip in `project-deployments/project-a/lambda/` unless your mentor asks you to practise layers or S3.

### Design decisions to consider

1. **Packaging choice** — Stay with `project-deployments/project-a/lambda/` + `publish.sh`, or layer / S3 (table above). Document which you picked.
2. **Library** — e.g. `jsonschema` in Python. How do you surface the first vs all validation errors to the officer-facing API?
3. **Strictness** — Envelope has `additionalProperties: false`. Will you strip unknown fields or reject them? Rejecting matches the contract spirit.
4. **Create vs update** — On create, do you require `request_id`/`created_at` from the client or set them server-side (and validate after enrichment)? Server-side enrichment then validate is a common pattern.
5. **Read paths** — Do `GET`s re-validate stored items (catch old bad data) or trust the store? Usually trust the store; optionally log if a stored item fails schema (`from logging_helpers import logger`).
6. **CloudWatch** — Route requests through `log_event(event)` so logs show `httpMethod`, `resource`, and `pathParameters`. Do not rebuild a second logger.

### Exit Layer B when

Invalid bodies never reach a successful write; at least one deliberate bad payload demo returns 4xx; schemas are loaded from `project-deployments/project-a/lambda/contracts/` (not reinvented inline as Python dicts).

---

## Layer C — DynamoDB data model

### Goal

Create **one** table (e.g. `sar-<you>-requests`) that supports your API access patterns.

DynamoDB is **access-pattern driven**. Choose keys from how you read data, not from a relational ERD of “document types.”

### Portal-driven access patterns (Phase 2)

| Access pattern    | API                     | Typical DynamoDB operation                       |
| ----------------- | ----------------------- | ------------------------------------------------ |
| Fetch one request | `GET /requests/{id}`    | `GetItem` by primary key                         |
| List requests     | `GET /requests`         | `Scan` (ok at sandbox scale) or `Query` on a GSI |
| Create            | `POST /requests`        | `PutItem` (condition: not exists)                |
| Update            | `PUT /requests/{id}`    | `PutItem` or `UpdateItem`                        |
| Delete            | `DELETE /requests/{id}` | `DeleteItem`                                     |

### Design decisions to consider

1. **Partition key (PK)** — For get-by-id, `request_id` (UUID string) as PK is the straightforward fit. Every item is a full SAR request document (envelope fields + `payload` map).
2. **Sort key (SK)** — Do you need one?
  - **PK only** — Simplest: one request = one item; `GetItem`/`DeleteItem`/`PutItem` by `request_id`. List = `Scan` (acceptable for training volumes).
  - **PK + SK** — Use if you model multiple items per request (e.g. metadata item + event items). More flexible, more complexity. Not required for Phase 2 if one item per request is enough.
3. **Attribute design** — Store the JSON document as attributes (and/or a `payload` map). Keep `document_type`, `status`, `created_at`, `requestor.officer_id` as top-level attributes if you will key or filter on them later.
4. **GSIs (only if needed)** — Add a GSI when `Scan` is not acceptable for a real query you must support. Examples:

  | If you must efficiently… | Example GSI                         |
  | ------------------------ | ----------------------------------- |
  | List by status           | PK `status`, SK `created_at`        |
  | List by officer          | PK `officer_id`, SK `created_at`    |
  | List by document type    | PK `document_type`, SK `created_at` |

   Each GSI has a cost and must be updated on write. **Do not** create three tables for three document types “just in case.”
5. **Item size & hot partitions** — UUID PK spreads load (good). Avoid a single hot PK like `ALL_REQUESTS` unless you understand the tradeoff.
6. **Capacity mode** — On-demand is fine for the sandbox unless your mentor asks otherwise.
7. **Naming & IAM** — Table name `sar-<you>-…`; ensure the **Lambda execution role** can read/write this table (mentor role may already allow `sar-`* patterns — confirm).

### Exit Layer C when

You can `GetItem`/`PutItem` a sample request from the AWS console or CLI using your chosen key schema, and you have written down PK/SK/GSI choices and why.

---

## Layer D — Repository wiring (Lambda ↔ DynamoDB)

### Goal

Implement the repository component so routes persist and load real items (no more stubs).

### Design decisions to consider

1. **Mapping** — API Gateway event → domain object → DynamoDB item (and reverse). Keep one obvious place for this mapping.
2. **Conditional writes** — `attribute_not_exists(request_id)` on create; optional version/condition on update to avoid silent overwrites.
3. **Not found** — Missing item on get/update/delete → `404` via your error path (refine in Phase 4).
4. **Timestamps** — Set `created_at` on create; bump `updated_at` on update; set `completed_at` when status reaches a terminal state (if you support that now).

### Exit Layer D when

Create → get → list → update → delete works via `curl` against the live API with data surviving cold starts.

---

## Layer E — Portal proof & C3 diagram

### Goal

Prove the stack through the UI and keep architecture honest.

1. Exercise **more than one** document type in the portal: create → list → open → edit → delete (`SAR_API_MODE=live`).
2. Update your **C3 Component** diagram: router, validator, repository (+ error handling stubs are fine until Phase 4). Walk the shape through with your mentor, who holds the target diagram.

---

## You are done with Phase 2 when

- [ ] Layers A–E complete; choices for API shape and DynamoDB keys noted for your mentor.
- [ ] Full CRUD works via the portal for multiple document types.
- [ ] Invalid envelopes/payloads return 4xx with a useful error body.
- [ ] Data survives Lambda cold starts (DynamoDB).
- [ ] Component diagram updated.

---

[Exercise summary](./phased-exercises.md) · Previous: [Phase 1 — Foundation & The C4 Model](./phase-1-foundation.md) · Next: [Phase 3 — Security & Identity](./phase-3-security.md)
