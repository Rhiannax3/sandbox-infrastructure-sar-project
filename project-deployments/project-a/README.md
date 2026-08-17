# Project A — Lambda

Work on your AWS Lambda here. The portal and your function share the JSON Schema files in [`lambda/contracts/`](./lambda/contracts/).

Do **not** rebuild the Django/Keycloak stack on the EC2 host. Edit Lambda source in this folder on your laptop (no local Python needed). Publishing installs `jsonschema` **on the sandbox host** and then calls `aws lambda update-function-code`.

## Layout

```text
project-deployments/
  project-a/
    README.md                 ← you are here
    lambda/
      example_lambda_function.py  ← template (copy this)
      lambda_function.py          ← your handler (gitignored)
      validate.py                 ← provided schema validation
      logging_helpers.py          ← provided CloudWatch logger
      requirements.txt            ← third-party packages (e.g. jsonschema)
      publish.sh                  ← zip + aws lambda update-function-code
      contracts/                  ← shared schemas (portal + Lambda)
        *.schema.json
```

Use the provided [`validate.py`](./lambda/validate.py) rather than rebuilding schema loading, and [`logging_helpers.py`](./lambda/logging_helpers.py) for CloudWatch output. After enriching a create body with `request_id` / `created_at` / `status`:

```python
from logging_helpers import log_event, logger
from validate import ContractError, parse_body, validate_request

log_event(event)
body = enrich_for_create(parse_body(event))
validate_request(body)
```

Invalid contracts raise `ContractError`; call `exc.to_response()` for a 400 JSON body. Extra modules you add (`repository.py`, …) stay **gitignored**; the host still zips whatever you uploaded.

## Write your function

1. Create the Lambda in AWS first (`sar-<you>-…`) and attach `lambda_execution_role_arn` from your mentor.
2. Set the handler to `lambda_function.lambda_handler` (Runtime settings).
3. Copy `example_lambda_function.py` to `lambda_function.py`, then edit that copy (and any extra `.py` files). Your copy and extra files are not committed to this repository. Import `validate.py` and `logging_helpers.py` as-is.
4. Keep validating against `lambda/contracts/` via `validate_request` — same files the portal mounts. Do not fork a second copy of the schemas.

`validate.py` already maps `document_type` to those files. You only need to enrich then call `validate_request`.

## Publish

`jsonschema` is installed on the **sandbox EC2 host** (it has Python). Your laptop only needs the AWS CLI, `tar`, and `ENGINEER_ID`.

```bash
cd project-deployments/project-a/lambda
# copy the example first if you have not already:
#   cp example_lambda_function.py lambda_function.py
ENGINEER_ID=<you> ./publish.sh sar-<you>-lambda          # region defaults to eu-west-2
# ENGINEER_ID=<you> ./publish.sh sar-<you>-lambda eu-west-2
```

The first publish installs `jsonschema` on the host and caches it under `.deps`. Later publishes reuse that cache unless `requirements.txt` changed.

If you are already in a Session Manager shell on the host:

```bash
cd /opt/sar-sandbox/lambda
./publish.sh sar-<you>-lambda
```

Ask your mentor to apply the Project A Terraform so the host role and junior policy include the publish permissions, and to start the instance if it auto-stopped. After a schema change, publish again so the zip matches the portal.

## Lambda console

The inline editor is optional for tiny stubs (package must stay under 3 MB unzipped). Prefer this directory + `publish.sh`. If you do use the console, copy `lambda_function.py`, `validate.py`, `logging_helpers.py`, extra modules, and the `contracts/` folder into the function and click **Deploy**.

## Alternatives (optional)

| Option | When |
|--------|------|
| **Zip via `publish.sh`** | Default for this programme |
| **Lambda layer** | Sharing schemas across several functions |
| **S3** | Update schemas without a code deploy (needs IAM + cache) |

See [Phase 2, Layer B](../../docs/developer/project-a/exercises/phase-2-core-api.md#layer-b--validation-contracts) in the SAR request exercises.
