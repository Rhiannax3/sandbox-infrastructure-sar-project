# Project A — C4 modelling skeleton

Complete these diagrams before / alongside each phase. Prefer Structurizr DSL, draw.io, or Mermaid.

Draw each level yourself first. Your mentor holds the target diagrams and will walk through them with you once you have a draft to compare against.

## What C4 is

C4 (Context, Containers, Components, Code) is a way of describing software architecture as a **set of diagrams at different zoom levels**, like moving from a world map to a street map. Each level answers one question for one audience, so no single diagram has to carry everything.

The discipline that makes it work is **one level of abstraction per diagram**. A box on your Context diagram is a whole system; on the Container diagram it becomes several deployable things; on the Component diagram one of those things becomes a handful of code modules. If you find yourself drawing a Lambda next to a compliance officer, you have mixed two levels and the diagram will be hard to read and harder to keep current.

Two conventions keep C4 diagrams reviewable:

- **Label every box with its type** — person, software system, container, or component — and note whether it is provided for you or something you build.
- **Label every arrow with intent and mechanism**, not just an arrowhead. "Reads and writes SAR requests — HTTPS plus Bearer JWT" tells a reviewer far more than a bare line.

## Why it helps when designing data systems

Data systems fail in the seams rather than in the middle of a service, and C4 is a cheap way to make those seams visible before you write code:

- **Trust boundaries become obvious.** Drawing the officer, the portal, Keycloak, and your API as separate systems forces the question of where a token is issued, where it is validated, and which hop is unauthenticated. That is exactly the gap Phase 3 asks you to close.
- **Data stores stop being an afterthought.** A container diagram makes you name the store, its access pattern, and who owns the data — so key design (`request_id`, `document_type`) is a decision you can defend rather than a side effect of the first `put_item` you wrote.
- **Contracts get a home.** Marking the shared JSON Schemas as a dependency of your validator shows why the portal and your API must not drift, and where a breaking change would land.
- **Personal data handling is explicit.** SAR payloads are subject data. When every flow that carries or logs it is drawn, over-logging or an unintended copy is visible on a diagram instead of buried in a handler.
- **It stays cheap to maintain.** Because each level is small, updating a diagram after a refactor is minutes of work, which is what keeps documentation trustworthy over the four phases.

## The four levels at a glance

| Level | Question it answers | Audience | Elements you draw | Keep off this level | In this project |
|-------|--------------------|----------|-------------------|---------------------|-----------------|
| **C1 — System Context** | What is this system, who uses it, and what does it depend on? | Mentors, non-technical reviewers | People and whole software systems | Any AWS service or internal technology | Officer, portal, your SAR Request API, Keycloak |
| **C2 — Container** | What runnable/deployable pieces make up my system, and how do they talk? | You and your mentor; anyone deploying it | Containers — apps, functions, APIs, data stores, log destinations | Code modules, classes | API Gateway, Lambda, DynamoDB, CloudWatch, JWT authorizer |
| **C3 — Component** | What are the major responsibilities inside one container? | You, while building and reviewing | Components — grouped code responsibilities | Every file and function | Router, validator, repository, scope checker, error mapper |
| **C4 — Code** | How is one component actually structured? | You, when a detail needs discussion | Modules, classes, key functions | Anything you would not maintain by hand | Optional sketch of the Lambda modules |

Rule of thumb on depth: C1 and C2 are worth keeping current for the life of the project, C3 is worth updating each phase, and C4 is a sketch you draw when a specific design question needs it.

## Level 1 — System Context

Actors and external systems:

- Compliance Officer (person)
- SAR Compliance Portal (software system) — *provided*
- SAR Request API (software system) — *you build*
- Identity Provider / Keycloak (software system) — *provided*
- Downstream analytics / Databricks (software system) — optional narrative peer to Project B; not a runtime dependency of this sandbox

**Task:** Draw relationships (uses, authenticates with, publishes logs to). Keep containers such as API Gateway, Lambda, and DynamoDB off this level.

## Level 2 — Containers

For the SAR Request API system, identify containers such as:

- API Gateway
- Lambda function(s)
- DynamoDB table
- CloudWatch Logs
- JWT authorizer (Phase 3)
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

## Level 4 — Code (optional depth)

Sketch modules/classes inside the Lambda components (handler, routes, validation, repository, errors). Names are yours to choose; aim for a structure you can defend in review.

## Deliverable

Work the phases in [SAR request exercises](./sar_request_exercises.md). Submit Context + Container diagrams after Phase 1, an updated Component diagram after Phase 2, and optionally a Code sketch when your mentor asks for implementation detail.
