# Data contracts

JSON Schema (draft 2020-12) definitions for Subject Access Request (SAR) payloads.

| File | Purpose |
|------|---------|
| `sar-request-envelope.schema.json` | Shared request envelope; `payload` is validated against the document-type schema |
| `user-profile-summary.schema.json` | Payload for `user_profile_summary` |
| `user-activity-report.schema.json` | Payload for `user_activity_report` |
| `user-consent-log.schema.json` | Payload for `user_consent_log` |

## Consumers

1. **Django SAR portal** — renders create/edit forms dynamically from these schemas.
2. **Engineer-built Lambda** (Project A, Phase 2) — validates incoming POST/PUT bodies against the matching schema.

Do not change field names or enums without coordinating both consumers. Adding optional fields is preferred over breaking changes.
