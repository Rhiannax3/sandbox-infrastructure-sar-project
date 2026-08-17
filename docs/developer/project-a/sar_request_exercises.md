# Project A — SAR request exercises

Phased delivery plan for the AWS API & Document Request System. Read the environment and integration seams in the [engineer runbook](./runbook.md) first, then work these phases with your mentor.

## Phased delivery plan

### Phase 1: Foundation & The C4 Model

**Theory & Context:** Before we build, we must plan. The C4 model is a standard way to draw architecture diagrams so everyone understands the system. Next, we introduce **Serverless** and **APIs**. Instead of renting a server that runs 24/7, we use AWS Lambda, which only runs (and bills us) when someone triggers it. API Gateway acts as the "front door," taking an HTTP web request from the Django portal and triggering your Lambda code. Finally, we use **Systems Manager (SSM)**. Instead of hard-coding your API's URL into the Django portal's source code, you save your URL in SSM. The portal looks up that parameter to find you. This is a crucial configuration best practice!

**Your Goals:**

1. Complete the Context and Container diagrams in the [C4 skeleton](./c4-skeleton.md).
2. Write a simple Python Lambda named `sar-<you>-hello` and attach `lambda_execution_role_arn`. Develop under [`project-deployments/project-a/lambda/`](../../../project-deployments/project-a/README.md) and publish with `ENGINEER_ID=<you> ./publish.sh sar-<you>-hello` (packaging runs on the sandbox host).
3. Create an API Gateway with `GET /health` pointing to your Lambda. Return JSON like `{"status":"ok","message":"Hello from <you>"}`.
4. Save the API **base URL** (include REST **stage** if applicable — see [runbook §4.1](./runbook.md#41-portal--your-api-ssm)) into SSM `/sar-sandbox/<you>/api-base-url`.
5. Confirm `curl "$URL/health"` returns 200, then ask your mentor to flip the portal to `SAR_API_MODE=live` and recreate Django.

**You are done when:**

- [x] Context + Container diagrams submitted / reviewed.
- [x] Portal header shows `API: live`.
- [x] Portal home shows **API health:** with your custom message (not mock, not a red error).
- [x] Resources named `sar-<you>-…`.

---



### Phase 2: Core API & Dynamic State

**Theory & Context:**

RESTful APIs use standard HTTP methods (`POST` to create, `GET` to read, `PUT` to update, `DELETE` to remove) to manage resources.

AWS Lambda is **stateless** — when an invocation finishes, in-memory state is gone. Persistent SAR requests need an external store: **DynamoDB**.

Bad input should fail fast. **JSON Schema contracts** in [`project-deployments/project-a/lambda/contracts/`](../../../project-deployments/project-a/lambda/contracts/) define the envelope and per–document-type payloads. Validate before you write.

Work this phase **one layer at a time**. At each layer, pause on the design decisions, note your choice for your mentor, then implement. Update your **C3 Component** diagram as the pieces appear (router → validator → repository).

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



#### Layer A — API surface (resource design)

**Goal:** Expand API Gateway + Lambda so the portal’s live client can call the paths in [runbook §4.2](./runbook.md#42-paths-the-portal-expects). Keep `GET /health` working.


| Method   | Path             | Portal use            |
| -------- | ---------------- | --------------------- |
| `GET`    | `/health`        | Home page health line |
| `GET`    | `/requests`      | List                  |
| `GET`    | `/requests/{id}` | Detail                |
| `POST`   | `/requests`      | Create                |
| `PUT`    | `/requests/{id}` | Update                |
| `DELETE` | `/requests/{id}` | Delete                |


**Design decisions to consider:**

1. **One resource vs three** — Prefer `/requests` for all document types. Separate `/user-profile-summaries` APIs fight the portal client and duplicate CRUD. Justify any divergence with your mentor first.
2. **REST vs HTTP API** — You may already have one from Phase 1. Stay consistent; remember REST base URLs in SSM must include the **stage**.
3. **One Lambda vs many** — A single function with an internal router is enough for this sandbox. Multiple functions are fine if you have a clear reason (blast radius, scaling) and still match the portal paths.
4. **IDs** — Who mints `request_id`? Portal/mock often expects a UUID on create. Prefer server-generated UUID on `POST` and return it in the body; reject client IDs that collide if you allow them.
5. **List semantics** — Unfiltered `GET /requests` is enough for Phase 2. Will you later filter by status, officer, or document type? That choice feeds Layer C (keys / GSIs).
6. **Idempotency & PUT** — Is `PUT` full replace of the envelope + payload, or partial patch? Full replace is simpler; document it. What happens on unknown `id`? (`404`)
7. **Status values** — Align with the envelope enum (`Draft`, `Submitted`, `In Progress`, `Pending Approval`, `Fulfilled`, `Rejected`, `Cancelled`). Which values can a standard officer set vs leave for Phase 3 approve flows?

**Exit Layer A when:** `curl` can hit each route (even if persistence is still in-memory or stubbed) and responses use JSON.

---



#### Layer B — Validation (contracts)

**Goal:** On `POST`/`PUT`, validate **before** DynamoDB writes.

1. Validate the **envelope** against `sar-request-envelope.schema.json`.
2. Read `document_type` and validate `payload` against the matching `user-*.schema.json`.
3. Unknown `document_type` or schema failure → **4xx** with a clear body (not a 500 stack trace).

##### Sharing the data contracts with your Lambda

Write your function in [`project-deployments/project-a/lambda/`](../../../project-deployments/project-a/README.md). Schemas already sit next to the handler at `lambda/contracts/` (the same files the portal mounts). Publish that folder — do not keep a second, divergent copy of the schemas.

**Edit and publish from this repo layout**

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

The script ships source to your sandbox host, which installs `requirements.txt` and runs `update-function-code`. Full steps: [`project-deployments/project-a/README.md`](../../../project-deployments/project-a/README.md).

**Schema changes:** edit `lambda/contracts/` once, then publish again so the zip matches the portal. Do not invent inline Python dicts as a second source of truth.

**Other options (when to use them)**

| Approach | How | Pros | Cons / when |
|----------|-----|------|-------------|
| **Zip from `project-deployments/project-a/lambda/`** (above) | Schemas already inside the package | Simple; no extra IAM; versioned with the function | Must republish to pick up schema edits |
| **Lambda layer** | Publish a layer with `/contracts` (or `python/contracts`) and attach it; read from `/opt/...` | Share across several functions; smaller function zips | Extra publish step; still update the layer version on schema change |
| **S3 object(s)** | Upload `contracts/` to e.g. `s3://sar-<you>-artifacts-…/contracts/`; Lambda `GetObject` on cold start and cache | Update schemas without a code deploy | Needs IAM + bucket; cache invalidation; more moving parts than this phase needs |

For Project A, prefer the zip in `project-deployments/project-a/lambda/` unless your mentor asks you to practise layers or S3.

**Design decisions to consider:**

1. **Packaging choice** — Stay with `project-deployments/project-a/lambda/` + `publish.sh`, or layer / S3 (table above). Document which you picked.
2. **Library** — e.g. `jsonschema` in Python. How do you surface the first vs all validation errors to the officer-facing API?
3. **Strictness** — Envelope has `additionalProperties: false`. Will you strip unknown fields or reject them? Rejecting matches the contract spirit.
4. **Create vs update** — On create, do you require `request_id`/`created_at` from the client or set them server-side (and validate after enrichment)? Server-side enrichment then validate is a common pattern.
5. **Read paths** — Do `GET`s re-validate stored items (catch old bad data) or trust the store? Usually trust the store; optionally log if a stored item fails schema (`from logging_helpers import logger`).
6. **CloudWatch** — Route requests through `log_event(event)` so logs show `httpMethod`, `resource`, and `pathParameters`. Do not rebuild a second logger.

**Exit Layer B when:** Invalid bodies never reach a successful write; at least one deliberate bad payload demo returns 4xx; schemas are loaded from `project-deployments/project-a/lambda/contracts/` (not reinvented inline as Python dicts).

---



#### Layer C — DynamoDB data model

**Goal:** Create **one** table (e.g. `sar-<you>-requests`) that supports your API access patterns.

DynamoDB is **access-pattern driven**. Choose keys from how you read data, not from a relational ERD of “document types.”

**Portal-driven access patterns (Phase 2):**


| Access pattern    | API                     | Typical DynamoDB operation                       |
| ----------------- | ----------------------- | ------------------------------------------------ |
| Fetch one request | `GET /requests/{id}`    | `GetItem` by primary key                         |
| List requests     | `GET /requests`         | `Scan` (ok at sandbox scale) or `Query` on a GSI |
| Create            | `POST /requests`        | `PutItem` (condition: not exists)                |
| Update            | `PUT /requests/{id}`    | `PutItem` or `UpdateItem`                        |
| Delete            | `DELETE /requests/{id}` | `DeleteItem`                                     |


**Design decisions to consider:**

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

**Exit Layer C when:** You can `GetItem`/`PutItem` a sample request from the AWS console or CLI using your chosen key schema, and you have written down PK/SK/GSI choices and why.

---



#### Layer D — Repository wiring (Lambda ↔ DynamoDB)

**Goal:** Implement the repository component so routes persist and load real items (no more stubs).

**Design decisions to consider:**

1. **Mapping** — API Gateway event → domain object → DynamoDB item (and reverse). Keep one obvious place for this mapping.
2. **Conditional writes** — `attribute_not_exists(request_id)` on create; optional version/condition on update to avoid silent overwrites.
3. **Not found** — Missing item on get/update/delete → `404` via your error path (refine in Phase 4).
4. **Timestamps** — Set `created_at` on create; bump `updated_at` on update; set `completed_at` when status reaches a terminal state (if you support that now).

**Exit Layer D when:** Create → get → list → update → delete works via `curl` against the live API with data surviving cold starts.

---



#### Layer E — Portal proof & C3 diagram

**Goal:** Prove the stack through the UI and keep architecture honest.

1. Exercise **more than one** document type in the portal: create → list → open → edit → delete (`SAR_API_MODE=live`).
2. Update your **C3 Component** diagram: router, validator, repository (+ error handling stubs are fine until Phase 4). Walk the shape through with your mentor, who holds the target diagram.

**You are done with Phase 2 when:**

- [ ] Layers A–E complete; choices for API shape and DynamoDB keys noted for your mentor.
- [ ] Full CRUD works via the portal for multiple document types.
- [ ] Invalid envelopes/payloads return 4xx with a useful error body.
- [ ] Data survives Lambda cold starts (DynamoDB).
- [ ] Component diagram updated.

---



### Phase 3: Security & Identity

**Theory & Context:**

Right now, anyone on the internet with your API URL could create a SAR request. We need to secure it using **Zero Trust** architecture.

When an officer logs into Keycloak, they receive a JSON Web Token (JWT) — a digital ID badge. It contains **scopes** (what they are allowed to do, like `sar:read` or `sar:approve`). Your API Gateway needs an **authorizer** that checks this badge *before* the request reaches Lambda.

**Your Goals:**

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

**You are done when:**

- [ ] Unauthenticated API calls fail.
- [ ] Authenticated portal flows still work with JWT mode on.
- [ ] Scope differences between standard and senior are demonstrable.
- [ ] Short write-up: which claims you trust and why.

---



### Phase 4: Resilience & Error Handling

**Theory & Context:**

In cloud engineering, things *will* break. Databases time out, networks drop. Professional APIs fail gracefully. Instead of a blank screen, your API must catch errors and return standard HTTP status codes (e.g. 404 Not Found, 500 Internal Error, 503 Service Unavailable) so the frontend can show a polite message.

**Your Goals:**

1. Introduce at least two controlled failure scenarios (examples: wrong DynamoDB table name, forced timeout, not-found vs validation vs conflict).
2. Catch exceptions and return clean JSON errors like `{"error":"...","code":"..."}` with the correct HTTP status (400 / 401 / 403 / 404 / 409 / 500 / 503 as appropriate). Log failures with the provided `logging_helpers.logger` so CloudWatch shows the cause without dumping a stack into the HTTP body.
3. Verify the portal shows a useful `SarApiError` / message instead of an opaque crash where you control the API.
4. **Theory exercise:** Write a short paper (length defined by mentor) on **AWS Lambda intra-region availability**: what AWS provides out of the box, what you still design for (retries, idempotency, multi-AZ data), and what this sandbox does *not* prove (e.g. multi-region active-active).

**You are done when:**

- [ ] Failure scenarios demoed with expected status codes.
- [ ] Portal shows understandable errors for those cases.
- [ ] Availability write-up submitted.
- [ ] C4 diagrams still match what you shipped.

---

