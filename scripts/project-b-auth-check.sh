#!/usr/bin/env bash
# Preflight checks for Project B (Azure / Databricks) CLI deploy.
# Run from repo root: bash scripts/project-b-auth-check.sh
# Safe to run from fish — script is bash.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_SHARED="${ROOT}/terraform/project-b-azure-shared/terraform.tfvars"
TF_ENGINEER="${ROOT}/terraform/project-b-azure-engineer/terraform.tfvars"

REQUIRED_PROVIDERS=(
  Microsoft.Storage
  Microsoft.Databricks
  Microsoft.Authorization
  Microsoft.Consumption
  Microsoft.Resources
)

fail=0

ok()   { printf '  OK   %s\n' "$*"; }
warn() { printf '  WARN %s\n' "$*"; }
err()  { printf '  FAIL %s\n' "$*"; fail=1; }

echo "==> Project B auth & preflight check"
echo

# --- Azure CLI ---
if ! command -v az >/dev/null 2>&1; then
  err "azure-cli not found (CachyOS: sudo pacman -S azure-cli)"
else
  ok "azure-cli: $(command -v az)"
fi

if ! az account show >/dev/null 2>&1; then
  err "not logged in — run: az login --tenant \"<tenant-id>\""
else
  az account show --query "{user:user.name, tenant:tenantId, subscription:name, subscriptionId:id}" -o table
  user="$(az account show --query user.name -o tsv)"
  if [[ "$user" == *@outlook.com ]] && [[ "$user" != *'#EXT#'* ]]; then
    warn "signed in as raw MSA ($user) — personal tenants usually need #EXT# Entra UPN for Databricks account APIs"
  fi
fi

# --- Subscription RBAC ---
if az account show >/dev/null 2>&1; then
  sub_id="$(az account show --query id -o tsv)"
  assignee="$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)"
  if [[ -n "$assignee" ]]; then
    roles="$(az role assignment list --assignee "$assignee" --scope "/subscriptions/${sub_id}" \
      --query "[].roleDefinitionName" -o tsv 2>/dev/null | tr '\n' ' ')"
    if [[ "$roles" == *Owner* ]] || [[ "$roles" == *Contributor* ]]; then
      ok "subscription RBAC: ${roles:-unknown}"
    else
      warn "no Owner/Contributor on subscription — provider register and resource create may fail"
    fi
  fi
fi

# --- #EXT# user (informational) ---
if az account show >/dev/null 2>&1; then
  ext_count="$(az ad user list --filter "contains(userPrincipalName,'#EXT#')" --query "length(@)" -o tsv 2>/dev/null || echo 0)"
  if [[ "$ext_count" -gt 0 ]]; then
    ok "found ${ext_count} #EXT# Entra user(s) in tenant"
    az ad user list --filter "contains(userPrincipalName,'#EXT#')" \
      --query "[].userPrincipalName" -o tsv 2>/dev/null | sed 's/^/       /'
  else
    warn "no #EXT# guest user found — see docs/platform-admin/project-b-cli-runbook.md Phase 1"
  fi
fi

echo
echo "==> Resource provider registration"
for ns in "${REQUIRED_PROVIDERS[@]}"; do
  state="$(az provider show --namespace "$ns" --query registrationState -o tsv 2>/dev/null || echo missing)"
  case "$state" in
    Registered) ok "$ns: Registered" ;;
    Registering) warn "$ns: Registering (wait and re-run)" ;;
    *) err "$ns: ${state} — run: az provider register --namespace $ns" ;;
  esac
done

echo
echo "==> Terraform tfvars"
account_id="${DATABRICKS_ACCOUNT_ID:-}"

if [[ -z "$account_id" ]] && [[ -f "$TF_SHARED" ]]; then
  account_id="$(grep -E '^databricks_account_id[[:space:]]*=' "$TF_SHARED" \
    | head -1 | sed -E 's/.*=[[:space:]]*"([^"]+)".*/\1/' || true)"
fi

if [[ -z "$account_id" ]] || [[ "$account_id" == "00000000-0000-0000-0000-000000000000" ]]; then
  err "databricks_account_id not set (export DATABRICKS_ACCOUNT_ID or edit shared terraform.tfvars)"
else
  ok "databricks_account_id: ${account_id}"
fi

if [[ -f "$TF_SHARED" ]]; then
  ok "shared terraform.tfvars present"
else
  warn "missing ${TF_SHARED} — copy from example.tfvars"
fi

if [[ -f "$TF_ENGINEER" ]]; then
  if grep -qE 'REPLACE_DATABRICKS_ACCOUNT_ID|00000000-0000-0000-0000-000000000000' "$TF_ENGINEER" 2>/dev/null; then
    warn "engineer terraform.tfvars has placeholder databricks_account_id"
  else
    ok "engineer terraform.tfvars present"
  fi
else
  warn "missing ${TF_ENGINEER} — required before make apply-b"
fi

echo
echo "==> Databricks account API (optional; needs databricks CLI + account admin)"
if ! command -v databricks >/dev/null 2>&1; then
  warn "databricks CLI not installed — skip account API check (Terraform still uses az login)"
elif [[ -z "$account_id" ]] || [[ "$account_id" == "00000000-0000-0000-0000-000000000000" ]]; then
  warn "cannot test account API without databricks_account_id"
else
  export DATABRICKS_HOST="${DATABRICKS_HOST:-https://accounts.azuredatabricks.net}"
  export DATABRICKS_ACCOUNT_ID="$account_id"
  export DATABRICKS_AUTH_TYPE="${DATABRICKS_AUTH_TYPE:-azure-cli}"
  if databricks account metastores list -o json >/dev/null 2>&1; then
    ok "account metastores list succeeded (account admin + auth OK)"
    databricks account metastores list -o json 2>/dev/null \
      | jq -r '.[] | "       \(.region): \(.metastore_id)"' 2>/dev/null || true
  else
    err "databricks account metastores list failed — check identity, Global Admin, account ID"
  fi
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "All required checks passed."
  exit 0
else
  echo "One or more checks failed — fix above before make apply-b-shared / apply-b."
  exit 1
fi
