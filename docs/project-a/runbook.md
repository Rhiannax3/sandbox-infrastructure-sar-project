# Project A — Engineer runbook

AWS API & Document Request System sandbox.

This track is **standalone** — you do not need Azure / Project B to complete the phases.

## What is already built for you

- EC2 host running **Django SAR portal** + **Keycloak** (Docker Compose, TLS via nip.io)
- IAM **Lambda execution role** you should attach to your functions
- IAM **junior developer policy** (ask your mentor to attach it to your principal)
- SSM parameter `/sar-sandbox/<you>/api-base-url` — publish your API Gateway URL here
- S3 log archive bucket for CloudWatch exports (optional; not required for Project B)
- JSON Schema contracts in `contracts/`

## What you must build (by phase)

| Phase | You build |
|-------|-----------|
| 1 | Hello World Lambda + API Gateway; wire portal (`SAR_API_MODE=live`) |
| 2 | CRUD API + DynamoDB + JSON Schema validation per document type |
| 3 | API Gateway JWT authorizer against Keycloak; scope checks |
| 4 | Resilience / error mapping; availability write-up |

## Getting your sandbox URL

After your mentor runs `make apply-a ENGINEER=<you>`:

```bash
cd terraform/project-a-aws
terraform workspace select <you>
terraform output
```

Key outputs: `portal_url`, `keycloak_url`, `lambda_execution_role_arn`, `api_base_url_parameter`.

## Test users (Keycloak)

| Username | Password | Role |
|----------|----------|------|
| `officer.standard` | `Password123!` | standard_officer |
| `officer.senior` | `Password123!` | senior_officer |

## Phase 1 checklist

1. Create Lambda named `sar-<you>-hello` using role from `lambda_execution_role_arn`.
2. Expose it via HTTP API Gateway with a `GET /health` route returning JSON.
3. Put the invoke URL into SSM:

```bash
aws ssm put-parameter \
  --name "/sar-sandbox/<you>/api-base-url" \
  --value "https://xxxxxxxx.execute-api.eu-west-2.amazonaws.com" \
  --type String --overwrite
```

4. Ask mentor to set `SAR_API_MODE=live` on the host (or use `app/compose/redeploy.sh`) and confirm the portal home page shows your health payload.

## Phase 2 hints

- Table name prefix: `sar-<you>-*`
- Validate bodies against `contracts/*.schema.json`
- Portal client methods to satisfy: `list/get/create/update/delete` in `sar/services/sar_api.py`

## Phase 3 hints

- Issuer: `https://<hostname>/auth/realms/sar-sandbox`
- Audience: `sar-api`
- Scopes: `sar:read`, `sar:write`, `sar:approve` (senior only)
- Flip `SAR_API_AUTH_ENABLED=true` once the authorizer works

## Do not

- Rebuild the Django app or Keycloak realm from scratch
- Create IAM users/keys (boundary will deny escalation)
- Use resources outside the `sar-<you>-*` naming convention
