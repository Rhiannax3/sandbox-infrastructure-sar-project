#!/bin/bash
# Patch the realm client secret from env before Keycloak imports the realm.
set -euo pipefail

REALM_SRC="/realm/realm-sar-sandbox.json"
IMPORT_DIR="/opt/keycloak/data/import"
mkdir -p "$IMPORT_DIR"

if [[ -n "${KEYCLOAK_CLIENT_SECRET:-}" ]]; then
  sed "s/CHANGE_ME_VIA_ENV/${KEYCLOAK_CLIENT_SECRET}/g" "$REALM_SRC" > "$IMPORT_DIR/realm-sar-sandbox.json"
else
  cp "$REALM_SRC" "$IMPORT_DIR/realm-sar-sandbox.json"
fi

exec /opt/keycloak/bin/kc.sh "$@"
