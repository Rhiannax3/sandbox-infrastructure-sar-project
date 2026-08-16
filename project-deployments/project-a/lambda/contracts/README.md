# Data contracts

JSON Schema (draft 2020-12) definitions for Subject Access Request (SAR) payloads. These files live inside the Lambda package so the same schemas are used by the portal and by your function.

| File | Purpose |
|------|---------|
| `sar-request-envelope.schema.json` | Shared request envelope; `payload` is validated against the document-type schema |
| `user-profile-summary.schema.json` | Payload for `user_profile_summary` |
| `user-activity-report.schema.json` | Payload for `user_activity_report` |
| `user-consent-log.schema.json` | Payload for `user_consent_log` |

## Consumers

1. **Django SAR portal** — renders create/edit forms from this folder (mounted on the EC2 host).
2. **Engineer-built Lambda** — validates POST/PUT bodies. Schemas unzip next to the handler at `/var/task/contracts`.

Do not change field names or enums without coordinating both consumers. Adding optional fields is preferred over breaking changes.

## Loading from Lambda

```python
from pathlib import Path
import json

CONTRACTS = Path(__file__).resolve().parent / "contracts"
```

| `document_type` | Schema file |
|-----------------|-------------|
| `user_profile_summary` | `user-profile-summary.schema.json` |
| `user_activity_report` | `user-activity-report.schema.json` |
| `user_consent_log` | `user-consent-log.schema.json` |

Write handler code in [`..`](../) (the `lambda/` folder) and publish with `./publish.sh`. Full steps: [`project-a/README.md`](../../README.md).
