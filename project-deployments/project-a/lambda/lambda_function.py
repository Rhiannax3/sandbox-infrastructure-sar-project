"""Project A Lambda handler.

Replace this stub with your SAR Request API. Keep extra modules in this
directory and import them as siblings, e.g. `from validate import validate_request`.

Publish with:  ./publish.sh sar-<you>-lambda
See ../README.md
"""

from __future__ import annotations

import json
from pathlib import Path

CONTRACTS_DIR = Path(__file__).resolve().parent / "contracts"


def lambda_handler(event, context):
    return {
        "statusCode": 501,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Not implemented. Edit project-deployments/project-a/lambda/ and run publish.sh.",
                "contracts_dir": str(CONTRACTS_DIR),
            }
        ),
    }
