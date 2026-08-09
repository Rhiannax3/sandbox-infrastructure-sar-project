# Django SAR Compliance Portal

Boilerplate web application for Project A. Juniors should not rebuild this — they
extend [`sar/services/sar_api.py`](sar/services/sar_api.py) and flip environment
flags as they progress through the phases.

## Modes

| Env var | Day-one default | Phase change |
|---------|-----------------|--------------|
| `SAR_API_MODE` | `mock` | `live` after Hello World API is reachable |
| `SAR_API_AUTH_ENABLED` | `false` | `true` in Phase 3 (Bearer JWT) |
| `SAR_API_BASE_URL` | empty | Optional override; otherwise read from SSM |

## Local development

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export DJANGO_DEBUG=true SAR_API_MODE=mock DJANGO_SECRET_KEY=dev
python manage.py migrate
python manage.py runserver
```

OIDC login requires Keycloak (see `app/compose`).
