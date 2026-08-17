"""Validate SAR request bodies against contracts/*.schema.json.

This module is provided with the project. Import it from your handler; do not
reimplement schema loading as ad-hoc Python dicts.

Run validate_request on the *enriched* object (request_id / created_at / status
already set on POST).
"""

from __future__ import annotations

import base64
import json
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import ValidationError
from referencing import Registry, Resource
from logging_helpers import logger

CONTRACTS_DIR = Path(__file__).resolve().parent / "contracts"
ENVELOPE_FILE = "sar-request-envelope.schema.json"
DOCUMENT_SCHEMAS = {
    "user_profile_summary": "user-profile-summary.schema.json",
    "user_activity_report": "user-activity-report.schema.json",
    "user_consent_log": "user-consent-log.schema.json",
}

_FORMAT = FormatChecker()
_REGISTRY: Registry | None = None
_SCHEMA_CACHE: dict[str, dict] = {}


def load_schema(name: str) -> dict:
    if name not in _SCHEMA_CACHE:
        with (CONTRACTS_DIR / name).open(encoding="utf-8") as handle:
            _SCHEMA_CACHE[name] = json.load(handle)
    return _SCHEMA_CACHE[name]


def _registry() -> Registry:
    global _REGISTRY
    if _REGISTRY is None:
        registry = Registry()
        for path in CONTRACTS_DIR.glob("*.schema.json"):
            schema = load_schema(path.name)
            resource = Resource.from_contents(schema)
            registry = registry.with_resource(schema["$id"], resource)
        _REGISTRY = registry
    return _REGISTRY


def _validator(schema: dict) -> Draft202012Validator:
    return Draft202012Validator(
        schema,
        registry=_registry(),
        format_checker=_FORMAT,
    )


class ContractError(Exception):
    """Raised when the body fails JSON Schema validation."""

    def __init__(self, message: str, errors: list[dict] | None = None):
        super().__init__(message)
        self.errors = errors or []

    def to_response(self) -> dict:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"message": str(self), "errors": self.errors}),
        }


def _error_item(exc: ValidationError) -> dict:
    path = ".".join(str(part) for part in exc.absolute_path) or "(root)"
    return {"path": path, "message": exc.message}


def _validate(instance: dict, schema: dict) -> None:
    errors = [_error_item(err) for err in _validator(schema).iter_errors(instance)]
    if errors:
        logger.error("Request body failed schema validation")
        for error in errors:
            logger.error("%s", error)
        raise ContractError("Request body failed schema validation", errors)


def parse_body(event: dict) -> dict:
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw)
    try:
        body = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ContractError("Body is not valid JSON") from exc
    if not isinstance(body, dict):
        raise ContractError("Request body must be a JSON object")
    return body


def validate_request(body: dict) -> None:
    """Validate an enriched SAR request (id/timestamps already set)."""
    if not isinstance(body, dict):
        raise ContractError("Request body must be a JSON object")

    document_type = body.get("document_type")
    if document_type not in DOCUMENT_SCHEMAS:
        raise ContractError(
            "Unknown or missing document_type",
            [
                {
                    "path": "document_type",
                    "message": f"Must be one of: {', '.join(DOCUMENT_SCHEMAS)}",
                }
            ],
        )

    _validate(body.get("payload") or {}, load_schema(DOCUMENT_SCHEMAS[document_type]))
    _validate(body, load_schema(ENVELOPE_FILE))
