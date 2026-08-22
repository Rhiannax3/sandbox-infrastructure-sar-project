#!/usr/bin/env bash
# Import permission_assignment resources when account groups already exist in workspace.
# Usage: bash scripts/project-b-import-permission-assignments.sh alex
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINEER="${1:?Usage: project-b-import-permission-assignments.sh <engineer-id>}"
TF_ENGINEER="${ROOT}/terraform/project-b-azure-engineer"

ROLES=(data_engineers analysts report_authors)

terraform_group_id() {
  local role="$1"
  (cd "$TF_ENGINEER" && terraform state show -no-color "module.workspace_config.databricks_group.${role}" 2>/dev/null \
    | awk -F'"' '/^id = / { print $2; exit }') || true
}

echo "==> Import permission_assignment for ${ENGINEER}"

(cd "$TF_ENGINEER" && terraform init -input=false >/dev/null)
(cd "$TF_ENGINEER" && terraform workspace select "$ENGINEER" 2>/dev/null) || {
  echo "ERROR: terraform workspace '${ENGINEER}' not found" >&2
  exit 1
}

imported=0
for role in "${ROLES[@]}"; do
  pid="$(terraform_group_id "$role")"
  if [[ -z "$pid" ]]; then
    echo "    ${role}: no account group in state — skip"
    continue
  fi
  if (cd "$TF_ENGINEER" && terraform state show "module.workspace_config.databricks_permission_assignment.${role}" >/dev/null 2>&1); then
    echo "    ${role}: permission_assignment already in state"
    continue
  fi
  echo "    ${role}: importing permission_assignment ${pid}"
  if (cd "$TF_ENGINEER" && terraform import "module.workspace_config.databricks_permission_assignment.${role}" "$pid"); then
    imported=$((imported + 1))
  else
    echo "    WARN: import failed — group may not be assigned to workspace yet" >&2
  fi
done

echo "Imported ${imported} permission_assignment resource(s)."
echo "If import failed, delete workspace-local groups first:"
echo "  bash scripts/project-b-delete-workspace-local-groups.sh ${ENGINEER}"
