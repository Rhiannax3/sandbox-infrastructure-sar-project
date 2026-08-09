from django.conf import settings


def portal_context(request):
    return {
        "sar_api_mode": settings.SAR_API_MODE,
        "sar_api_auth_enabled": settings.SAR_API_AUTH_ENABLED,
        "engineer_id": settings.ENGINEER_ID,
    }
