"""Load JSON Schema contracts for dynamic form rendering and client-side hints."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

from django.conf import settings

ENVELOPE = "sar-request-envelope.schema.json"
DOCUMENT_SCHEMAS = {
    "user_profile_summary": "user-profile-summary.schema.json",
    "user_activity_report": "user-activity-report.schema.json",
    "user_consent_log": "user-consent-log.schema.json",
}


def _contracts_dir() -> Path:
    return Path(settings.CONTRACTS_DIR)


@lru_cache(maxsize=16)
def load_schema(filename: str) -> dict:
    path = _contracts_dir() / filename
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def envelope_schema() -> dict:
    return load_schema(ENVELOPE)


def payload_schema(document_type: str) -> dict:
    try:
        filename = DOCUMENT_SCHEMAS[document_type]
    except KeyError as exc:
        raise ValueError(f"Unknown document type: {document_type}") from exc
    return load_schema(filename)


def humanize_document_type(document_type: str) -> str:
    """Display label for a document_type enum value (snake_case → Title Case)."""
    return document_type.replace("_", " ").title()


def document_type_choices() -> list[tuple[str, str]]:
    schema = envelope_schema()
    enum_values = schema["properties"]["document_type"]["enum"]
    return [(value, humanize_document_type(value)) for value in enum_values]


def priority_choices() -> list[tuple[str, str]]:
    schema = envelope_schema()
    enum_values = schema["properties"]["priority"]["enum"]
    return [(value, value.title()) for value in enum_values]


def payload_field_defs(document_type: str) -> list[dict]:
    """Flatten payload schema properties into template-friendly field definitions."""
    schema = payload_schema(document_type)
    required = set(schema.get("required") or [])
    fields = []
    for name, prop in (schema.get("properties") or {}).items():
        fields.append(
            {
                "name": name,
                "title": prop.get("title") or name.replace("_", " ").title(),
                "description": prop.get("description", ""),
                "type": prop.get("type", "string"),
                "format": prop.get("format"),
                "enum": prop.get("enum"),
                "items": prop.get("items"),
                "required": name in required,
                "default": prop.get("default"),
            }
        )
    return fields
