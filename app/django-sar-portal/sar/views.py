from __future__ import annotations

import json

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect, render
from django.views.decorators.http import require_http_methods

from sar.services import contracts
from sar.services.sar_api import DOCUMENT_TYPES, SarApiError, get_client


def _access_token(request: HttpRequest) -> str | None:
    return request.session.get("oidc_access_token")


def portal_home(request: HttpRequest) -> HttpResponse:
    client = get_client(_access_token(request))
    health = None
    health_error = None
    try:
        health = client.health()
    except SarApiError as exc:
        health_error = str(exc)

    return render(
        request,
        "sar/home.html",
        {
            "health": health,
            "health_error": health_error,
            "document_cards": contracts.document_type_cards(),
        },
    )


@login_required
def request_list(request: HttpRequest) -> HttpResponse:
    client = get_client(_access_token(request))
    try:
        items = client.list_requests()
    except SarApiError as exc:
        messages.error(request, f"Could not list requests: {exc}")
        items = []
    return render(request, "sar/request_list.html", {"items": items})


@login_required
@require_http_methods(["GET", "POST"])
def request_create(request: HttpRequest) -> HttpResponse:
    document_type = request.GET.get("document_type") or request.POST.get("document_type")
    if document_type not in DOCUMENT_TYPES:
        return render(
            request,
            "sar/request_create_choose.html",
            {"choices": contracts.document_type_cards()},
        )

    field_defs = contracts.payload_field_defs(document_type)
    if request.method == "POST":
        payload = _build_payload_from_post(request, document_type, field_defs)
        client = get_client(_access_token(request))
        try:
            created = client.create_request(payload)
            messages.success(request, f"Created request {created['request_id']}")
            return redirect("request_detail", request_id=created["request_id"])
        except SarApiError as exc:
            messages.error(request, f"Create failed ({exc.status_code}): {exc}")

    return render(
        request,
        "sar/request_form.html",
        {
            "document_type": document_type,
            "field_defs": contracts.annotate_payload_values(field_defs, None),
            "priorities": contracts.priority_choices(),
            "statuses": contracts.status_choices(),
            "mode": "create",
            "item": {},
            "subject": {},
            "requestor": {},
        },
    )


@login_required
@require_http_methods(["GET", "POST"])
def request_edit(request: HttpRequest, request_id: str) -> HttpResponse:
    client = get_client(_access_token(request))
    try:
        item = client.get_request(request_id)
    except SarApiError as exc:
        messages.error(request, str(exc))
        return redirect("request_list")

    document_type = item.get("document_type")
    if document_type not in DOCUMENT_TYPES:
        messages.error(request, "This request has an unknown document type.")
        return redirect("request_detail", request_id=request_id)

    field_defs = contracts.payload_field_defs(document_type)
    if request.method == "POST":
        payload = _build_payload_from_post(request, document_type, field_defs)
        payload["request_id"] = request_id
        payload["status"] = request.POST.get("status") or item.get("status") or "Submitted"
        if item.get("created_at"):
            payload["created_at"] = item["created_at"]
        try:
            updated = client.update_request(request_id, payload)
            rid = request_id
            if isinstance(updated, dict) and updated.get("request_id"):
                rid = updated["request_id"]
            messages.success(request, f"Updated request {rid}")
            return redirect("request_detail", request_id=rid)
        except SarApiError as exc:
            messages.error(request, f"Update failed ({exc.status_code}): {exc}")
            item = {**item, **payload}

    subject = item.get("subject") or {}
    requestor = item.get("requestor") or {}
    return render(
        request,
        "sar/request_form.html",
        {
            "document_type": document_type,
            "field_defs": contracts.annotate_payload_values(field_defs, item.get("payload")),
            "priorities": contracts.priority_choices(),
            "statuses": contracts.status_choices(),
            "mode": "edit",
            "item": item,
            "subject": subject,
            "requestor": requestor,
        },
    )


@login_required
def request_detail(request: HttpRequest, request_id: str) -> HttpResponse:
    client = get_client(_access_token(request))
    try:
        item = client.get_request(request_id)
    except SarApiError as exc:
        messages.error(request, str(exc))
        return redirect("request_list")
    return render(
        request,
        "sar/request_detail.html",
        {"item": item, "item_json": json.dumps(item, indent=2)},
    )


@login_required
@require_http_methods(["POST"])
def request_delete(request: HttpRequest, request_id: str) -> HttpResponse:
    client = get_client(_access_token(request))
    try:
        client.delete_request(request_id)
        messages.success(request, f"Deleted {request_id}")
    except SarApiError as exc:
        messages.error(request, f"Delete failed: {exc}")
    return redirect("request_list")


def _build_payload_from_post(request: HttpRequest, document_type: str, field_defs: list) -> dict:
    """Assemble envelope + document payload from the dynamic form POST body."""
    doc_payload: dict = {}
    for field in field_defs:
        name = field["name"]
        raw = request.POST.getlist(name) if field.get("items") else request.POST.get(name)

        if field["type"] == "boolean":
            doc_payload[name] = request.POST.get(name) == "on"
        elif field.get("items") and isinstance(raw, list):
            doc_payload[name] = raw
        elif raw not in (None, ""):
            doc_payload[name] = raw

    user = request.user
    return {
        "document_type": document_type,
        "priority": request.POST.get("priority", "Medium"),
        "notes": request.POST.get("notes", ""),
        "subject": {
            "subject_id": request.POST.get("subject_id", "SUBJ-UNKNOWN"),
            "email": request.POST.get("subject_email", "subject@example.com"),
            "display_name": request.POST.get("subject_display_name", ""),
        },
        "requestor": {
            "officer_id": request.POST.get("officer_id", "OFF-UNKNOWN"),
            "email": user.email or "officer@sar-sandbox.local",
            "role": "Senior Officer" if user.is_staff else "Standard Officer",
        },
        "payload": doc_payload,
    }
