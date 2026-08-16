# Data contracts

JSON Schema (draft 2020-12) definitions for Subject Access Request (SAR) payloads.

| File | Purpose |
|------|---------|
| `sar-request-envelope.schema.json` | Shared request envelope; `payload` is validated against the document-type schema |
| `user-profile-summary.schema.json` | Payload for `user_profile_summary` |
| `user-activity-report.schema.json` | Payload for `user_activity_report` |
| `user-consent-log.schema.json` | Payload for `user_consent_log` |

## Consumers

1. **Django SAR portal** — renders create/edit forms dynamically from these schemas (mounted on the EC2 host from this folder).
2. **Engineer-built Lambda** (Project A, Phase 2) — validates incoming POST/PUT bodies against the matching schema.

Do not change field names or enums without coordinating both consumers. Adding optional fields is preferred over breaking changes.

## Using these files from Lambda

The portal can read this directory on disk. Your Lambda runs in AWS and only sees what you **deploy or fetch**. Keep this folder as the source of truth.

### Recommended: copy into the deployment zip

```text
your-function/
  handler.py
  contracts/          # copy of this directory’s *.schema.json files
    sar-request-envelope.schema.json
    …
```

```bash
cp -r /path/to/repo/contracts ./contracts
pip install jsonschema -t .
zip -r function.zip . -x '*.pyc' -x '__pycache__/*'
aws lambda update-function-code --function-name sar-<you>-… --zip-file fileb://function.zip
```

Load relative to the handler:

```python
from pathlib import Path
import json

CONTRACTS = Path(__file__).resolve().parent / "contracts"
```

Document-type → file mapping (same as the portal):

| `document_type` | Schema file |
|-----------------|-------------|
| `user_profile_summary` | `user-profile-summary.schema.json` |
| `user_activity_report` | `user-activity-report.schema.json` |
| `user_consent_log` | `user-consent-log.schema.json` |

After any schema change in git, refresh the copy in your function package and **redeploy**.

### Alternatives

| Option | Idea |
|--------|------|
| **Lambda layer** | Put schemas under `/opt/...` in a layer; attach to one or more functions |
| **S3** | Store schemas in your artifact bucket; `GetObject` + in-memory cache on cold start (needs IAM) |

Zip bundling is enough for the programme sandbox. See Phase 2 Layer B in [`docs/project-a/sar_request_exercises.md`](../docs/project-a/sar_request_exercises.md).
