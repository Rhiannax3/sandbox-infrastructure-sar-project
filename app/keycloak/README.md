# Keycloak realm — sar-sandbox

Imported at container start via `--import-realm`.

## Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `sar-portal` | Confidential | Django OIDC login (authorization code + PKCE) |
| `sar-api` | Public / audience | JWT `aud` claim for API Gateway authorizer (Phase 3) |

The portal client secret is set at deploy time from SSM / Compose env (`OIDC_RP_CLIENT_SECRET`). The realm JSON placeholder `CHANGE_ME_VIA_ENV` is overwritten by the entrypoint script in Compose.

## Roles

- `standard_officer` — create/read/update own SAR requests (`sar:read`, `sar:write`)
- `senior_officer` — composite of standard + `sar:approve`

## Test users (password for both: `Password123!`)

| Username | Role | Officer ID |
|----------|------|------------|
| `officer.standard` | standard_officer | OFF-001 |
| `officer.senior` | senior_officer | OFF-002 |

## Scopes

- `sar:read` — list/get requests
- `sar:write` — create/update/delete
- `sar:approve` — approve pending requests (mapped to senior_officer only)
