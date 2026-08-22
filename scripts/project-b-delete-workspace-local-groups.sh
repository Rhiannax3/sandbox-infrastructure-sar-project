#!/usr/bin/env bash
# Delete legacy workspace-local groups that block account-group permission_assignment.
# Workspace-local groups from a failed apply share names with account groups but are
# a different object — groups-v2 delete often cannot remove them; SCIM API can.
#
# Usage:
#   bash scripts/project-b-delete-workspace-local-groups.sh alex
#   WS_URL=adb-xxx.azuredatabricks.net bash scripts/project-b-delete-workspace-local-groups.sh alex
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINEER="${1:?Usage: project-b-delete-workspace-local-groups.sh <engineer-id>}"
PREFIX="sar-${ENGINEER}"
RG="${RG:-rg-${PREFIX}}"
WS_NAME="${WS_NAME:-dbw-${PREFIX}}"

GROUPS=(
  "${PREFIX}-data-engineers"
  "${PREFIX}-analysts"
  "${PREFIX}-report-authors"
)

DATABRICKS_AAD_RESOURCE="${DATABRICKS_AAD_RESOURCE:-2ff814a6-3304-4ab8-85cb-cd0e6f879c1d}"

az_token() {
  az account get-access-token --resource "$DATABRICKS_AAD_RESOURCE" --query accessToken -o tsv
}

resolve_ws_url() {
  if [[ -n "${WS_URL:-}" ]]; then
    local u="${WS_URL#https://}"
    u="${u#http://}"
    printf '%s' "$u"
    return 0
  fi
  local url
  url="$(az databricks workspace show -g "$RG" -n "$WS_NAME" --query workspaceUrl -o tsv 2>/dev/null)" || return 1
  printf '%s' "$url"
}

scim_list_group_id() {
  local host="$1" name="$2" token="$3"
  local encoded
  encoded="$(python3 -c "import urllib.parse; print(urllib.parse.quote('displayName eq \"$name\"'))")"
  curl -sS "https://${host}/api/2.0/preview/scim/v2/Groups?filter=${encoded}" \
    -H "Authorization: Bearer ${token}" \
    | jq -r '.Resources[0].id // empty'
}

scim_delete_group() {
  local host="$1" id="$2" token="$3"
  local code
  code="$(curl -sS -o /tmp/scim-group-del.json -w '%{http_code}' -X DELETE \
    "https://${host}/api/2.0/preview/scim/v2/Groups/${id}" \
    -H "Authorization: Bearer ${token}")"
  echo "$code"
}

echo "==> Delete workspace-local groups blocking permission_assignment (${ENGINEER})"

HOST="$(resolve_ws_url)" || {
  echo "ERROR: could not resolve workspace URL (set WS_URL or check rg-sar-${ENGINEER})" >&2
  exit 1
}
echo "    Workspace host: ${HOST}"

TOKEN="$(az_token)"
[[ -n "$TOKEN" ]] || { echo "ERROR: az login required" >&2; exit 1; }

export DATABRICKS_HOST="https://${HOST}"
export DATABRICKS_AUTH_TYPE="${DATABRICKS_AUTH_TYPE:-azure-cli}"

remaining=0

for name in "${GROUPS[@]}"; do
  echo
  echo "--- ${name} ---"

  # Attempt 1: Databricks CLI groups-v2 (works for some workspace group types)
  if command -v databricks >/dev/null 2>&1; then
    gid="$(databricks groups-v2 list -o json 2>/dev/null | jq -r --arg n "$name" '.[] | select(.displayName==$n) | .id' | head -1 || true)"
    if [[ -n "$gid" && "$gid" != "null" ]]; then
      echo "    groups-v2: delete ${gid}"
      if databricks groups-v2 delete "$gid" 2>/tmp/gv2-del.err; then
        echo "    groups-v2: deleted"
        continue
      else
        echo "    groups-v2: failed — $(cat /tmp/gv2-del.err)"
      fi
    else
      echo "    groups-v2: not listed"
    fi
  fi

  # Attempt 2: Workspace SCIM API (legacy workspace-local groups)
  scim_id="$(scim_list_group_id "$HOST" "$name" "$TOKEN" || true)"
  if [[ -n "$scim_id" ]]; then
    echo "    SCIM: delete ${scim_id}"
    code="$(scim_delete_group "$HOST" "$scim_id" "$TOKEN")"
    if [[ "$code" == "204" || "$code" == "200" ]]; then
      echo "    SCIM: deleted (${code})"
      continue
    else
      echo "    SCIM: delete failed HTTP ${code}: $(cat /tmp/scim-group-del.json 2>/dev/null || true)"
    fi
  else
    echo "    SCIM: not listed"
  fi

  # Still present?
  if scim_id="$(scim_list_group_id "$HOST" "$name" "$TOKEN" 2>/dev/null)" && [[ -n "$scim_id" ]]; then
    echo "    STILL PRESENT after delete attempts (id=${scim_id})" >&2
    remaining=$((remaining + 1))
  else
    echo "    OK: no longer listed via SCIM"
  fi
done

echo
if [[ "$remaining" -gt 0 ]]; then
  echo "ERROR: ${remaining} group(s) still block permission_assignment." >&2
  echo "List all sar-* groups:" >&2
  curl -sS "https://${HOST}/api/2.0/preview/scim/v2/Groups" \
    -H "Authorization: Bearer ${TOKEN}" \
    | jq '.Resources[] | select(.displayName|startswith("sar-")) | {id, displayName}' >&2 || true
  exit 1
fi

echo "All target workspace-local groups cleared (or were already absent)."
