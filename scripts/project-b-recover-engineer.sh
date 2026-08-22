#!/usr/bin/env bash
# Recover a partial Project B engineer apply via CLI (no Azure Portal).
# Deletes workspace-local stale groups, optionally stuck SQL warehouse, then re-applies.
#
# Usage (from repo root, fish or bash):
#   bash scripts/project-b-recover-engineer.sh alex
#   bash scripts/project-b-recover-engineer.sh alex --delete-warehouse
#
# Requires: az login, databricks CLI, terraform init on shared stack, engineer terraform.tfvars
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINEER="${1:?Usage: project-b-recover-engineer.sh <engineer-id> [--delete-warehouse]}"
DELETE_WAREHOUSE=0
if [[ "${2:-}" == "--delete-warehouse" ]]; then
  DELETE_WAREHOUSE=1
fi

RG="sar-${ENGINEER}"
WS_NAME="dbw-sar-${ENGINEER}"
PREFIX="sar-${ENGINEER}"
TF_SHARED="${ROOT}/terraform/project-b-azure-shared"
TF_ENGINEER_TFVARS="${ROOT}/terraform/project-b-azure-engineer/terraform.tfvars"

GROUPS=(
  "${PREFIX}-data-engineers"
  "${PREFIX}-analysts"
  "${PREFIX}-report-authors"
)
WAREHOUSE_NAME="${PREFIX}-sql"

echo "==> Project B engineer recovery: ${ENGINEER}"
echo "    Resource group: ${RG}  Workspace: ${WS_NAME}"
echo

command -v az >/dev/null || { echo "ERROR: az not found" >&2; exit 1; }
command -v databricks >/dev/null || { echo "ERROR: databricks CLI not found" >&2; exit 1; }
az account show >/dev/null || { echo "ERROR: az login required" >&2; exit 1; }

[[ -f "$TF_ENGINEER_TFVARS" ]] || {
  echo "ERROR: missing ${TF_ENGINEER_TFVARS}" >&2
  exit 1
}

echo "==> Resolve workspace URL"
WS_URL="$(az databricks workspace show -g "$RG" -n "$WS_NAME" --query workspaceUrl -o tsv 2>/dev/null)" || {
  echo "ERROR: workspace ${WS_NAME} not found in ${RG}" >&2
  exit 1
}
echo "    https://${WS_URL}"

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
