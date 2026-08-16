# Project A — Lambda

Work on your AWS Lambda here. The portal and your function share the JSON Schema files in [`lambda/contracts/`](./lambda/contracts/).

Do **not** write Lambda code on the EC2 sandbox host (`/opt/sar-sandbox`). That tree is the provided Django/Keycloak stack. Develop in this directory on your laptop, then publish the zip to AWS.

## Layout

```text
project-deployments/
  project-a/
    README.md                 ← you are here
    lambda/
      example_lambda_function.py  ← template (copy this)
      lambda_function.py          ← your handler (gitignored)
      validate.py                 ← provided schema validation
      requirements.txt            ← third-party packages (e.g. jsonschema)
      publish.sh                  ← zip + aws lambda update-function-code
      contracts/                  ← shared schemas (portal + Lambda)
        *.schema.json
```

Use the provided [`validate.py`](./lambda/validate.py) rather than rebuilding schema loading. After enriching a create body with `request_id` / `created_at` / `status`:

```python
from validate import ContractError, parse_body, validate_request

body = enrich_for_create(parse_body(event))
validate_request(body)
```

Invalid contracts raise `ContractError`; call `exc.to_response()` for a 400 JSON body. Extra modules you add (`repository.py`, …) stay **gitignored**; `publish.sh` still zips whatever is on disk.

## Write your function

1. Create the Lambda in AWS first (`sar-<you>-…`) and attach `lambda_execution_role_arn` from your mentor.
2. Set the handler to `lambda_function.lambda_handler` (Runtime settings).
3. Copy `example_lambda_function.py` to `lambda_function.py`, then edit that copy (and any extra `.py` files). Your copy and extra files are not committed to this repository. Import `validate.py` as-is.
4. Keep validating against `lambda/contracts/` via `validate_request` — same files the portal mounts. Do not fork a second copy of the schemas.

`validate.py` already maps `document_type` to those files. You only need to enrich then call `validate_request`.

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

The inline editor is optional for tiny stubs (package must stay under 3 MB unzipped). Prefer this directory + `publish.sh`. If you do use the console, copy `lambda_function.py`, `validate.py`, extra modules, and the `contracts/` folder into the function and click **Deploy**.

## Alternatives (optional)

| Option | When |
|--------|------|
| **Zip via `publish.sh`** | Default for this programme |
| **Lambda layer** | Sharing schemas across several functions |
| **S3** | Update schemas without a code deploy (needs IAM + cache) |

See Phase 2 Layer B in [`docs/project-a/sar_request_exercises.md`](../../docs/project-a/sar_request_exercises.md).
