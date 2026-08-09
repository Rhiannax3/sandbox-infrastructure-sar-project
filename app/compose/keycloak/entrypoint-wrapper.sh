#!/bin/bash
# Patch the realm client secret and portal redirect URI before Keycloak imports.
set -euo pipefail

REALM_SRC="/realm/realm-sar-sandbox.json"
IMPORT_DIR="/opt/keycloak/data/import"
mkdir -p "$IMPORT_DIR"

HOSTNAME_VALUE="${HOSTNAME:-localhost}"
REDIRECT_URI="https://${HOSTNAME_VALUE}/oidc/callback/"

tmp="$(mktemp)"
cp "$REALM_SRC" "$tmp"

if [[ -n "${KEYCLOAK_CLIENT_SECRET:-}" ]]; then
  sed -i "s/CHANGE_ME_VIA_ENV/${KEYCLOAK_CLIENT_SECRET}/g" "$tmp"
fi

# nip.io hosts have many DNS labels; Keycloak does not treat https://*/... as valid.
sed -i "s|REDIRECT_URI_PLACEHOLDER|${REDIRECT_URI}|g" "$tmp"

mv "$tmp" "$IMPORT_DIR/realm-sar-sandbox.json"

exec /opt/keycloak/bin/kc.sh "$@"
