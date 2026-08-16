"""Example Project A Lambda handler.

Copy this file to lambda_function.py (gitignored) and replace the stub
with your SAR Request API. Schema checks use the provided validate.py.

Publish with:  ./publish.sh sar-<you>-lambda
See ../README.md
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone

from validate import ContractError, parse_body, validate_request


def enrich_for_create(body: dict) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    return {
        **body,
        "request_id": str(uuid.uuid4()),
        "status": body.get("status") or "Submitted",
        "created_at": now,
        "updated_at": now,
        "completed_at": body.get("completed_at"),
    }


def lambda_handler(event, context):
    method = (event.get("httpMethod") or "").upper()
    if method in ("POST", "PUT"):
        try:
            body = parse_body(event)
            if method == "POST":
                body = enrich_for_create(body)
            validate_request(body)
        except ContractError as exc:
            return exc.to_response()
        return {
            "statusCode": 501,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {
                    "message": "Validated; persist to DynamoDB next.",
                    "request_id": body.get("request_id"),
                }
            ),
        }

    return {
        "statusCode": 501,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "message": "Not implemented. Copy this file to lambda_function.py and add your routes.",
            }
        ),
    }
