from __future__ import annotations

from datetime import datetime

from django import template

from sar.services.contracts import humanize_document_type, humanize_label

register = template.Library()

_STATUS_CLASS = {
    "Draft": "status-draft",
    "Submitted": "status-submitted",
    "In Progress": "status-progress",
    "Pending Approval": "status-pending",
    "Fulfilled": "status-fulfilled",
    "Rejected": "status-rejected",
    "Cancelled": "status-cancelled",
}

_PRIORITY_CLASS = {
    "Low": "priority-low",
    "Medium": "priority-medium",
    "High": "priority-high",
    "Critical": "priority-critical",
}


@register.filter(name="document_type_label")
def document_type_label(value: str | None) -> str:
    if not value:
        return ""
    return humanize_document_type(str(value))


@register.filter(name="enum_label")
def enum_label(value: str | None) -> str:
    if not value:
        return ""
    return humanize_label(str(value))


@register.filter(name="status_class")
def status_class(value: str | None) -> str:
    return _STATUS_CLASS.get(str(value or ""), "status-draft")


@register.filter(name="priority_class")
def priority_class(value: str | None) -> str:
    return _PRIORITY_CLASS.get(str(value or ""), "priority-medium")


@register.filter(name="iso_datetime")
def iso_datetime(value: str | None) -> str:
    if not value:
        return "—"
    raw = str(value).replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(raw)
    except ValueError:
        return str(value)[:19].replace("T", " ")
    return dt.strftime("%d %b %Y, %H:%M")


@register.filter(name="display_value")
def display_value(value) -> str:
    if value is True:
        return "Yes"
    if value is False:
        return "No"
    if value is None or value == "":
        return "—"
    if isinstance(value, (list, tuple)):
        return ", ".join(str(item) for item in value) or "—"
    return str(value)
