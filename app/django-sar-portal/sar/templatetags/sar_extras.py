from __future__ import annotations

from django import template

from sar.services.contracts import humanize_document_type, humanize_label

register = template.Library()


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
