# Phase 1: Foundation & The C4 Model

Phase 1 of the [SAR request exercises](./phased-exercises.md). Environment and integration seams are in the [engineer runbook](../runbook.md).

## Theory and context

Before we build, we must plan. The C4 model is a standard way to draw architecture diagrams so everyone understands the system. Next, we introduce **Serverless** and **APIs**. Instead of renting a server that runs 24/7, we use AWS Lambda, which only runs (and bills us) when someone triggers it. API Gateway acts as the "front door," taking an HTTP web request from the Django portal and triggering your Lambda code. Finally, we use **Systems Manager (SSM)**. Instead of hard-coding your API's URL into the Django portal's source code, you save your URL in SSM. The portal looks up that parameter to find you. This is a crucial configuration best practice!

## Your goals

1. Complete the Context and Container diagrams in the [C4 skeleton](../c4-skeleton.md).
2. Write a simple Python Lambda named `sar-<you>-hello` and attach `lambda_execution_role_arn`. Develop under [`project-deployments/project-a/lambda/`](../../../../project-deployments/project-a/README.md) and publish with `ENGINEER_ID=<you> ./publish.sh sar-<you>-hello` (packaging runs on the sandbox host).
3. Create an API Gateway with `GET /health` pointing to your Lambda. Return JSON like `{"status":"ok","message":"Hello from <you>"}`.
4. Save the API **base URL** (include REST **stage** if applicable — see [runbook §4.1](../runbook.md#41-portal--your-api-ssm)) into SSM `/sar-sandbox/<you>/api-base-url`.
5. Confirm `curl "$URL/health"` returns 200, then ask your mentor to flip the portal to `SAR_API_MODE=live` and recreate Django.

## You are done when

- [x] Context + Container diagrams submitted / reviewed.
- [x] Portal header shows `API: live`.
- [x] Portal home shows **API health:** with your custom message (not mock, not a red error).
- [x] Resources named `sar-<you>-…`.

---

[Exercise summary](./phased-exercises.md) · Next: [Phase 2 — Core API & Dynamic State](./phase-2-core-api.md)
