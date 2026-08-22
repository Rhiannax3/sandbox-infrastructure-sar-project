#!/usr/bin/env bash
# Recover a partial Project B engineer apply via CLI (no Azure Portal).
# Deletes workspace-local stale groups, optionally stuck SQL warehouse, then re-applies.
#
# Usage (from repo root, fish or bash):
#   bash scripts/project-b-recover-engineer.sh alex
#   bash scripts/project-b-recover-engineer.sh alex --delete-warehouse
#
# Optional env overrides (if auto-discovery fails):
#   RG=rg-sar-alex WS_NAME=dbw-sar-alex bash scripts/project-b-recover-engineer.sh alex
#
# Requires: az login, databricks CLI, terraform init on shared stack, engineer terraform.tfvars
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINEER="${1:?Usage: project-b-recover-engineer.sh <engineer-id> [--delete-warehouse]}"
DELETE_WAREHOUSE=0
if [[ "${2:-}" == "--delete-warehouse" ]]; then
  DELETE_WAREHOUSE=1
fi

# Terraform naming: rg-{prefix}, dbw-{prefix} where prefix = sar-{engineer_id}
PREFIX="sar-${ENGINEER}"
RG="${RG:-rg-${PREFIX}}"
WS_NAME="${WS_NAME:-dbw-${PREFIX}}"
TF_SHARED="${ROOT}/terraform/project-b-azure-shared"
TF_ENGINEER="${ROOT}/terraform/project-b-azure-engineer"
TF_ENGINEER_TFVARS="${ROOT}/terraform/project-b-azure-engineer/terraform.tfvars"

GROUPS=(
  "${PREFIX}-data-engineers"
  "${PREFIX}-analysts"
  "${PREFIX}-report-authors"
)
WAREHOUSE_NAME="${PREFIX}-sql"

echo "==> Project B engineer recovery: ${ENGINEER}"
echo "    Resource group (expected): ${RG}  Workspace (expected): ${WS_NAME}"
echo

command -v az >/dev/null || { echo "ERROR: az not found" >&2; exit 1; }
command -v databricks >/dev/null || { echo "ERROR: databricks CLI not found" >&2; exit 1; }
az account show >/dev/null || { echo "ERROR: az login required" >&2; exit 1; }

[[ -f "$TF_ENGINEER_TFVARS" ]] || {
  echo "ERROR: missing ${TF_ENGINEER_TFVARS}" >&2
  exit 1
}

normalize_host() {
  local u="$1"
  u="${u#https://}"
  u="${u#http://}"
  u="${u%/}"
  printf '%s' "$u"
}

resolve_workspace_url() {
  local url="" rg="" name="$WS_NAME"

  # 1) Terraform state (best — matches what apply created)
  if (cd "$TF_ENGINEER" && terraform init -input=false >/dev/null 2>&1); then
    (cd "$TF_ENGINEER" && terraform workspace select "$ENGINEER" >/dev/null 2>&1) || true
    url="$(cd "$TF_ENGINEER" && terraform output -raw databricks_workspace_url 2>/dev/null || true)"
    rg="$(cd "$TF_ENGINEER" && terraform output -raw resource_group_name 2>/dev/null || true)"
    if [[ -n "$url" && "$url" != "null" ]]; then
      printf '%s\n' "$(normalize_host "$url")" "${rg:-$RG}" "$name"
      return 0
    fi
  fi

  # 2) Expected Azure names (rg-sar-{id}, dbw-sar-{id})
  if url="$(az databricks workspace show -g "$RG" -n "$WS_NAME" --query workspaceUrl -o tsv 2>/dev/null)"; then
    printf '%s\n' "$(normalize_host "$url")" "$RG" "$WS_NAME"
    return 0
  fi

  # 3) Legacy/wrong RG name (sar-{id} without rg- prefix)
  local legacy_rg="$PREFIX"
  if [[ "$legacy_rg" != "$RG" ]] && url="$(az databricks workspace show -g "$legacy_rg" -n "$WS_NAME" --query workspaceUrl -o tsv 2>/dev/null)"; then
    printf '%s\n' "$(normalize_host "$url")" "$legacy_rg" "$WS_NAME"
    return 0
  fi

  # 4) List any Databricks workspace in expected RG
  if az group show -n "$RG" >/dev/null 2>&1; then
    local line
    line="$(az databricks workspace list -g "$RG" --query "[0].{name:name,url:workspaceUrl}" -o tsv 2>/dev/null || true)"
    if [[ -n "$line" ]]; then
      name="$(echo "$line" | awk '{print $1}')"
      url="$(echo "$line" | awk '{print $2}')"
      printf '%s\n' "$(normalize_host "$url")" "$RG" "$name"
      return 0
    fi
  fi

  return 1
}

echo "==> Resolve workspace URL"
mapfile -t _resolved < <(resolve_workspace_url || true)
if [[ ${#_resolved[@]} -ge 3 ]]; then
  WS_URL="${_resolved[0]}"
  RG="${_resolved[1]}"
  WS_NAME="${_resolved[2]}"
  echo "    Resource group: ${RG}"
  echo "    Workspace:      ${WS_NAME}"
  echo "    URL:            https://${WS_URL}"
else
  echo "ERROR: could not find Databricks workspace for engineer '${ENGINEER}'" >&2
  echo >&2
  echo "Expected Azure names (from Terraform):" >&2
  echo "  Resource group: rg-sar-${ENGINEER}   (not sar-${ENGINEER})" >&2
  echo "  Workspace:      dbw-sar-${ENGINEER}" >&2
  echo >&2
  echo "Discovery commands:" >&2
  echo "  az group list -o table | grep sar" >&2
  echo "  az databricks workspace list -g rg-sar-${ENGINEER} -o table" >&2
  echo "  terraform -chdir=terraform/project-b-azure-engineer workspace select ${ENGINEER}" >&2
  echo "  terraform -chdir=terraform/project-b-azure-engineer output resource_group_name" >&2
  exit 1
fi

export DATABRICKS_HOST="https://${WS_URL}"
export DATABRICKS_AUTH_TYPE="${DATABRICKS_AUTH_TYPE:-azure-cli}"

echo
echo "==> List workspace groups"
databricks groups-v2 list -o json | jq '.[] | {id, displayName}' || true

echo
echo "==> Delete workspace-local stale groups (if present)"
for name in "${GROUPS[@]}"; do
  id="$(databricks groups-v2 list -o json | jq -r --arg n "$name" '.[] | select(.displayName==$n) | .id' | head -1)"
  if [[ -n "$id" && "$id" != "null" ]]; then
    echo "    deleting group ${name} (${id})"
    databricks groups-v2 delete "$id" || echo "    WARN: delete failed for ${name} (may be account-level — skip)"
  else
    echo "    not found in workspace: ${name}"
  fi
done

if [[ "$DELETE_WAREHOUSE" -eq 1 ]]; then
  echo
  echo "==> Delete stuck SQL warehouse (if present)"
  wh_id="$(databricks warehouses list -o json | jq -r --arg n "$WAREHOUSE_NAME" '.[] | select(.name==$n) | .id' | head -1)"
  if [[ -n "$wh_id" && "$wh_id" != "null" ]]; then
    echo "    deleting warehouse ${WAREHOUSE_NAME} (${wh_id})"
    databricks warehouses delete "$wh_id" || echo "    WARN: warehouse delete failed"
  else
    echo "    warehouse not found: ${WAREHOUSE_NAME}"
  fi
fi

echo
echo "==> Load shared outputs"
cd "$TF_SHARED"
terraform init -input=false >/dev/null 2>&1 || terraform init -input=false
METASTORE_ID="$(terraform output -raw metastore_id)"
ACCESS_CONNECTOR_ID="$(terraform output -raw access_connector_id)"
ACCESS_CONNECTOR_PRINCIPAL_ID="$(terraform output -raw access_connector_principal_id)"

[[ -n "$METASTORE_ID" && -n "$ACCESS_CONNECTOR_ID" && -n "$ACCESS_CONNECTOR_PRINCIPAL_ID" ]] || {
  echo "ERROR: shared outputs missing — run make apply-b-shared first" >&2
  exit 1
}

echo "    METASTORE_ID=${METASTORE_ID}"
echo
echo "==> Re-apply engineer stack"
cd "$ROOT"
make apply-b ENGINEER="$ENGINEER" \
  METASTORE_ID="$METASTORE_ID" \
  ACCESS_CONNECTOR_ID="$ACCESS_CONNECTOR_ID" \
  ACCESS_CONNECTOR_PRINCIPAL_ID="$ACCESS_CONNECTOR_PRINCIPAL_ID"

echo
echo "==> Recovery complete for ${ENGINEER}"
