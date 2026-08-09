"""
SAR API client seam.

Engineers extend this module as they progress through Project A phases:

  Phase 1 — Flip SAR_API_MODE=live after publishing the Hello World API URL to SSM.
  Phase 2 — Ensure list/create/get/update/delete map to your REST resources.
  Phase 3 — SAR_API_AUTH_ENABLED=true attaches the OIDC access token as Bearer.
  Phase 4 — Surface structured API errors (status codes) in the portal UI.

Do not rename the public methods; the views depend on this interface.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

import requests
from django.conf import settings

from sar.services.ssm import get_api_base_url

logger = logging.getLogger(__name__)

DOCUMENT_TYPES = (
    "user_profile_summary",
    "user_activity_report",
    "user_consent_log",
)


class SarApiError(Exception):
    def __init__(self, message: str, status_code: int | None = None, body: Any = None):
        super().__init__(message)
        self.status_code = status_code
        self.body = body


class SarApiClient:
    """Client used by portal views. Switch mock/live via settings.SAR_API_MODE."""

    def __init__(self, access_token: str | None = None):
        self.access_token = access_token
        self.mode = settings.SAR_API_MODE
        self._mock_store: dict[str, dict] = _MOCK_STORE

    # -- public interface ----------------------------------------------------

    def health(self) -> dict:
        if self.mode == "mock":
            return {"status": "ok", "mode": "mock", "message": "Hello from mock SAR API"}
        return self._request("GET", "/health")

    def list_requests(self) -> list[dict]:
        if self.mode == "mock":
            return sorted(self._mock_store.values(), key=lambda r: r["created_at"], reverse=True)
        data = self._request("GET", "/requests")
        return data if isinstance(data, list) else data.get("items", [])

    def get_request(self, request_id: str) -> dict:
        if self.mode == "mock":
            try:
                return self._mock_store[request_id]
            except KeyError as exc:
                raise SarApiError("Request not found", status_code=404) from exc
        return self._request("GET", f"/requests/{request_id}")

    def create_request(self, payload: dict) -> dict:
        if self.mode == "mock":
            now = datetime.now(timezone.utc).isoformat()
            record = {
                "request_id": str(uuid.uuid4()),
                "status": "submitted",
                "created_at": now,
                "updated_at": now,
                "completed_at": None,
                **payload,
            }
            self._mock_store[record["request_id"]] = record
            return record
        return self._request("POST", "/requests", json=payload)

    def update_request(self, request_id: str, payload: dict) -> dict:
        if self.mode == "mock":
            existing = self.get_request(request_id)
            existing.update(payload)
            existing["updated_at"] = datetime.now(timezone.utc).isoformat()
            self._mock_store[request_id] = existing
            return existing
        return self._request("PUT", f"/requests/{request_id}", json=payload)

    def delete_request(self, request_id: str) -> None:
        if self.mode == "mock":
            self.get_request(request_id)
            del self._mock_store[request_id]
            return
        self._request("DELETE", f"/requests/{request_id}")

    # -- HTTP helpers --------------------------------------------------------

    def _base_url(self) -> str:
        if settings.SAR_API_BASE_URL_OVERRIDE:
            return settings.SAR_API_BASE_URL_OVERRIDE.rstrip("/")
        url = get_api_base_url()
        if not url or url.startswith("https://placeholder"):
            raise SarApiError(
                "API base URL not configured. Set SSM parameter "
                f"{settings.SSM_API_BASE_URL_PARAM} or SAR_API_BASE_URL, "
                "or keep SAR_API_MODE=mock.",
                status_code=503,
            )
        return url.rstrip("/")

    def _headers(self) -> dict[str, str]:
        headers = {"Accept": "application/json", "Content-Type": "application/json"}
        if settings.SAR_API_AUTH_ENABLED and self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"
        return headers

    def _request(self, method: str, path: str, **kwargs) -> Any:
        url = f"{self._base_url()}{path}"
        try:
            response = requests.request(
                method,
                url,
                headers=self._headers(),
                timeout=15,
                **kwargs,
            )
        except requests.RequestException as exc:
            logger.exception("SAR API request failed: %s %s", method, url)
            raise SarApiError(f"Upstream request failed: {exc}", status_code=502) from exc

        if response.status_code == 204:
            return None
        if response.status_code >= 400:
            try:
                body = response.json()
            except ValueError:
                body = response.text
            raise SarApiError(
                f"API returned {response.status_code}",
                status_code=response.status_code,
                body=body,
            )
        if not response.content:
            return None
        return response.json()


# Process-local mock store so the portal is usable before any Lambda exists.
_MOCK_STORE: dict[str, dict] = {}


def get_client(access_token: str | None = None) -> SarApiClient:
    return SarApiClient(access_token=access_token)
