"""Django settings for the SAR compliance portal sandbox."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent


def env(key: str, default: str | None = None) -> str | None:
    return os.environ.get(key, default)


def env_bool(key: str, default: bool = False) -> bool:
    return env(key, str(default)).lower() in {"1", "true", "yes", "on"}


SECRET_KEY = env("DJANGO_SECRET_KEY", "dev-only-change-me")
DEBUG = env_bool("DJANGO_DEBUG", False)

HOSTNAME = env("HOSTNAME", "localhost")
ALLOWED_HOSTS = [
    HOSTNAME,
    "localhost",
    "127.0.0.1",
    "django",
    *env("DJANGO_ALLOWED_HOSTS", "").split(","),
]
ALLOWED_HOSTS = [h.strip() for h in ALLOWED_HOSTS if h.strip()]

CSRF_TRUSTED_ORIGINS = [
    f"https://{HOSTNAME}",
    f"http://{HOSTNAME}",
    "http://localhost:8000",
]

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "mozilla_django_oidc",
    "sar",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "mozilla_django_oidc.middleware.SessionRefresh",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "sar.context_processors.portal_context",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-gb"
TIME_ZONE = "Europe/London"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ---------------------------------------------------------------------------
# OIDC / Keycloak
# ---------------------------------------------------------------------------

AUTHENTICATION_BACKENDS = (
    "sar.auth.SarOIDCAuthenticationBackend",
    "django.contrib.auth.backends.ModelBackend",
)

KEYCLOAK_BASE_URL = env("KEYCLOAK_BASE_URL", f"https://{HOSTNAME}/auth")
OIDC_REALM = env("OIDC_REALM", "sar-sandbox")
OIDC_OP_BASE = f"{KEYCLOAK_BASE_URL}/realms/{OIDC_REALM}"

OIDC_RP_CLIENT_ID = env("OIDC_RP_CLIENT_ID", "sar-portal")
OIDC_RP_CLIENT_SECRET = env("OIDC_RP_CLIENT_SECRET", "CHANGE_ME_VIA_ENV")
OIDC_RP_SIGN_ALGO = "RS256"
OIDC_RP_SCOPES = "openid profile email sar:read sar:write"

OIDC_OP_AUTHORIZATION_ENDPOINT = f"{OIDC_OP_BASE}/protocol/openid-connect/auth"
OIDC_OP_TOKEN_ENDPOINT = f"{OIDC_OP_BASE}/protocol/openid-connect/token"
OIDC_OP_USER_ENDPOINT = f"{OIDC_OP_BASE}/protocol/openid-connect/userinfo"
OIDC_OP_JWKS_ENDPOINT = f"{OIDC_OP_BASE}/protocol/openid-connect/certs"
OIDC_OP_LOGOUT_ENDPOINT = f"{OIDC_OP_BASE}/protocol/openid-connect/logout"

LOGIN_URL = "oidc_authentication_init"
LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/"
ALLOW_LOGOUT_GET_METHOD = True
OIDC_STORE_ACCESS_TOKEN = True
OIDC_STORE_ID_TOKEN = True

# ---------------------------------------------------------------------------
# SAR API client — engineers extend sar/services/sar_api.py
# ---------------------------------------------------------------------------

ENGINEER_ID = env("ENGINEER_ID", "demo")
AWS_REGION = env("AWS_REGION", "eu-west-2")

# mock = in-memory store (day one); live = call API Gateway URL from SSM
SAR_API_MODE = env("SAR_API_MODE", "mock")
SAR_API_AUTH_ENABLED = env_bool("SAR_API_AUTH_ENABLED", False)
SAR_API_BASE_URL_OVERRIDE = env("SAR_API_BASE_URL", "")
SSM_API_BASE_URL_PARAM = f"/sar-sandbox/{ENGINEER_ID}/api-base-url"

CONTRACTS_DIR = Path(env("CONTRACTS_DIR", str(BASE_DIR.parent.parent / "contracts")))
if not CONTRACTS_DIR.exists():
    CONTRACTS_DIR = Path("/contracts")

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {"class": "logging.StreamHandler"},
    },
    "root": {
        "handlers": ["console"],
        "level": env("LOG_LEVEL", "INFO"),
    },
}
