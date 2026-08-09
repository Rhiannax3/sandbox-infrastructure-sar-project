"""OIDC backend that maps Keycloak realm roles onto Django groups/flags."""

from __future__ import annotations

import logging

from mozilla_django_oidc.auth import OIDCAuthenticationBackend

logger = logging.getLogger(__name__)


class SarOIDCAuthenticationBackend(OIDCAuthenticationBackend):
    def filter_users_by_claims(self, claims):
        email = claims.get("email")
        if not email:
            return self.UserModel.objects.none()
        return self.UserModel.objects.filter(email__iexact=email)

    def create_user(self, claims):
        user = super().create_user(claims)
        self._apply_claims(user, claims)
        return user

    def update_user(self, user, claims):
        self._apply_claims(user, claims)
        return user

    def _apply_claims(self, user, claims) -> None:
        user.email = claims.get("email", user.email)
        user.first_name = claims.get("given_name", "")
        user.last_name = claims.get("family_name", "")

        realm_access = claims.get("realm_access") or {}
        roles = set(realm_access.get("roles") or [])
        # Also accept top-level roles claim used by some mappers
        roles.update(claims.get("roles") or [])

        user.is_staff = "senior_officer" in roles
        user.save()

        logger.info(
            "OIDC login for %s with roles=%s",
            user.email,
            sorted(roles),
        )

    def get_userinfo(self, access_token, id_token, payload):
        userinfo = super().get_userinfo(access_token, id_token, payload)
        # Preserve realm roles from the access token payload when present
        if "realm_access" in payload and "realm_access" not in userinfo:
            userinfo["realm_access"] = payload["realm_access"]
        return userinfo
