# Project A — Lambda

Work on your AWS Lambda here. The portal and your function share the JSON Schema files in [`lambda/contracts/`](./lambda/contracts/).

Do **not** write Lambda code on the EC2 sandbox host (`/opt/sar-sandbox`). That tree is the provided Django/Keycloak stack. Develop in this directory on your laptop, then publish the zip to AWS.

## Layout

```text
project-deployments/
  project-a/
    README.md                 ← you are here
    lambda/
      lambda_function.py      ← handler (replace the stub)
      requirements.txt        ← third-party packages (e.g. jsonschema)
      publish.sh              ← zip + aws lambda update-function-code
      contracts/              ← shared schemas (portal + Lambda)
        *.schema.json
```

Add extra modules next to the handler (`validate.py`, `repository.py`, …). Import them as siblings:

```python
from validate import validate_request
```

Those files must live **in this folder** (they unzip to `/var/task`). You cannot import from a parent directory or from the EC2 host. Extra modules and build artefacts are **gitignored** so they stay out of this repo; `publish.sh` still zips whatever is on disk.

## Write your function

1. Create the Lambda in AWS first (`sar-<you>-…`) and attach `lambda_execution_role_arn` from your mentor.
2. Set the handler to `lambda_function.lambda_handler` (Runtime settings).
3. Edit `lambda/lambda_function.py` (and any extra `.py` files). Extra files are not committed to this repository.
4. Keep validating against `lambda/contracts/` — same files the portal mounts. Do not fork a second copy of the schemas.

Runtime schema path (works in `/var/task` after you publish):

```python
from pathlib import Path

CONTRACTS_DIR = Path(__file__).resolve().parent / "contracts"
```

| `document_type` | Schema file |
|-----------------|-------------|
| `user_profile_summary` | `user-profile-summary.schema.json` |
| `user_activity_report` | `user-activity-report.schema.json` |
| `user_consent_log` | `user-consent-log.schema.json` |

## Publish

From a machine with the AWS CLI and the junior developer policy (not an SSM session on the sandbox host):

```bash
cd project-deployments/project-a/lambda
./publish.sh sar-<you>-lambda          # region defaults to eu-west-2
# ./publish.sh sar-<you>-lambda eu-west-2
```

The script installs `requirements.txt` into a gitignored `.build/` directory, zips **python files + `contracts/` + dependencies**, and runs `aws lambda update-function-code`. Confirm with:

```bash
aws sts get-caller-identity
# should not be the EC2 instance role sar-<you>-sandbox-host
```

After a schema change, publish again so the function zip matches the portal.

## Lambda console

The inline editor is optional for tiny stubs (package must stay under 3 MB unzipped). Prefer this directory + `publish.sh`. If you do use the console, copy the same files (`lambda_function.py`, extra modules, and the `contracts/` folder) into the function and click **Deploy**.

## Alternatives (optional)

| Option | When |
|--------|------|
| **Zip via `publish.sh`** | Default for this programme |
| **Lambda layer** | Sharing schemas across several functions |
| **S3** | Update schemas without a code deploy (needs IAM + cache) |

See Phase 2 Layer B in [`docs/project-a/sar_request_exercises.md`](../../docs/project-a/sar_request_exercises.md).
