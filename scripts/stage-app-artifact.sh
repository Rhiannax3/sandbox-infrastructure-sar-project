#!/usr/bin/env bash
# Stage portal/Keycloak/contracts for upload to the EC2 host.
# No Docker required — the instance builds and runs Compose.
#
# Usage:
#   stage-app-artifact.sh <destination-dir>
#   stage-app-artifact.sh --terraform-external <destination-dir>
#     (prints JSON for Terraform data.external)
set -euo pipefail

EXTERNAL=0
if [[ "${1:-}" == "--terraform-external" ]]; then
  EXTERNAL=1
  shift
fi

DEST="${1:?Usage: stage-app-artifact.sh [--terraform-external] <destination-dir>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$DEST"
mkdir -p "$DEST"

cp -a "$ROOT/app/compose" "$DEST/compose"
cp -a "$ROOT/app/django-sar-portal" "$DEST/django-sar-portal"
cp -a "$ROOT/app/keycloak" "$DEST/keycloak"
cp -a "$ROOT/project-deployments/project-a/lambda/contracts" "$DEST/contracts"

find "$DEST" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
find "$DEST" -type d -name '.venv' -prune -exec rm -rf {} + 2>/dev/null || true
find "$DEST" -type f \( -name '*.pyc' -o -name '.env' \) -delete 2>/dev/null || true

if [[ "$EXTERNAL" -eq 1 ]]; then
  # data.external requires a flat string map on stdout
  printf '{"staged":"true","path":"%s"}\n' "$DEST"
else
  echo "Staged app artifact at $DEST"
fi
