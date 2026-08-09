"""Resolve the engineer-built API Gateway base URL from SSM Parameter Store."""

from __future__ import annotations

import logging

from django.conf import settings

logger = logging.getLogger(__name__)

_cache: dict[str, str] = {}


def get_api_base_url() -> str:
    """Return the API base URL, preferring env override then SSM."""
    if settings.SAR_API_BASE_URL_OVERRIDE:
        return settings.SAR_API_BASE_URL_OVERRIDE

    param = settings.SSM_API_BASE_URL_PARAM
    if param in _cache:
        return _cache[param]

    try:
        import boto3

        client = boto3.client("ssm", region_name=settings.AWS_REGION)
        response = client.get_parameter(Name=param)
        value = response["Parameter"]["Value"]
        _cache[param] = value
        return value
    except Exception as exc:  # noqa: BLE001 — sandbox should degrade gracefully
        logger.warning("Could not read SSM parameter %s: %s", param, exc)
        return ""


def clear_cache() -> None:
    _cache.clear()
