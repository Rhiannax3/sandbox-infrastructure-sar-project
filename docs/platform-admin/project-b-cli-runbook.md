# Project B — CLI-first runbook (fish)

**CLI-only** path for Project B (Azure / Databricks). No Azure Portal navigation after initial `az login` OAuth.

For portal-based steps (legacy), see [Project B (Azure) runbook](./project-b-azure-runbook.md). For stage-based navigation, see [deployment stages](./project-b-deployment-stages.md).

**Shell:** interactive commands use **fish** syntax. The repo [`Makefile`](../../Makefile) runs targets under bash — invoke `make` from fish normally. Helper scripts are bash; run with `bash scripts/...`.

---

## Quick start

```fish
# 1. Preflight (from repo root)
bash scripts/project-b-auth-check.sh

# 2. After shared apply — load outputs in fish
make b-shared-env-fish | source

# 3. Engineer apply
make apply-b ENGINEER=alex \
  METASTORE_ID=$METASTORE_ID \
  ACCESS_CONNECTOR_ID=$ACCESS_CONNECTOR_ID \
  ACCESS_CONNECTOR_PRINCIPAL_ID=$ACCESS_CONNECTOR_PRINCIPAL_ID

# 4. Partial apply recovery
bash scripts/project-b-recover-engineer.sh alex
```

---

## Constraints (personal MSA + CachyOS)

| Topic | Guidance |
|-------|----------|
| Identity | Use `#EXT#` Entra UPN, not raw `@outlook.com`, for Databricks account APIs |
| Azure CLI | `sudo pacman -S azure-cli` — use `/usr/bin/az`, not a broken `~/.local/bin/az` |
| Terraform auth | `auth_type = "azure-cli"` — same session as `az login`; no `databricks auth login` for apply |
| Account ID | Databricks account UUID — **not** Azure subscription ID; store in tfvars once known |
| Fish env | `set -x VAR value` — not `export`; use `make b-shared-env-fish` or `terraform -chdir=… output -raw` |

---

## Phase 0 — Tooling

```fish
sudo pacman -S azure-cli make python terraform jq
/usr/bin/az version
terraform version   # >= 1.9
```

Optional (recovery / day-2 checks):

```fish
yay -S databricks-cli-bin
databricks -v
```

Persist known values in `~/.config/fish/config.fish` (do not commit secrets):

```fish
set -x AZURE_LOCATION uksouth
set -x DATABRICKS_ACCOUNT_ID "<your-databricks-account-uuid>"
set -x DATABRICKS_AUTH_TYPE azure-cli
```

---

## Phase 1 — Authentication

### 1a. Sign in and pick subscription

```fish
az login --tenant "<YOUR-TENANT-ID>"
az account list -o table
set -x SUBSCRIPTION_ID "<subscription-guid>"
az account set --subscription $SUBSCRIPTION_ID
az account show --query "{user:user.name, tenant:tenantId, subscription:id}" -o jsonc
```

### 1b. Find and use `#EXT#` deploy identity

```fish
az ad user list --filter "contains(userPrincipalName,'#EXT#')" \
  --query "[].{upn:userPrincipalName, id:id}" -o table
set -x EXT_UPN "<you_outlook.com#EXT#@tenant.onmicrosoft.com>"

az logout
az login --tenant "<YOUR-TENANT-ID>" --username $EXT_UPN
az account set --subscription $SUBSCRIPTION_ID
```

### 1c. Global Administrator (one-time, personal tenants)

```fish
az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
  --body '{"roleTemplateId":"62e90394-69f5-4237-9190-012177145e10"}' \
  2>/dev/null; or true

set ROLE_ID (az rest --method GET --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
  --query "value[?roleTemplateId=='62e90394-69f5-4237-9190-012177145e10'].id" -o tsv)

set USER_ID (az ad user show --id $EXT_UPN --query id -o tsv)

az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/directoryRoles/$ROLE_ID/members/\$ref" \
  --headers "Content-Type=application/json" \
  --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/$USER_ID\"}"
```

### 1d. Verify

```fish
bash scripts/project-b-auth-check.sh

set -x DATABRICKS_HOST https://accounts.azuredatabricks.net
set -x DATABRICKS_ACCOUNT_ID "<your-uuid>"
set -x DATABRICKS_AUTH_TYPE azure-cli
databricks account metastores list -o json
```

---

## Phase 2 — Preflight

### Register providers

```fish
for ns in Microsoft.Storage Microsoft.Databricks Microsoft.Authorization \
          Microsoft.Consumption Microsoft.Resources
  echo "Registering $ns ..."
  az provider register --namespace $ns
end

for ns in Microsoft.Storage Microsoft.Databricks
  az provider show --namespace $ns --query registrationState -o tsv
end
```

### Tfvars

```fish
cp terraform/project-b-azure-shared/example.tfvars \
   terraform/project-b-azure-shared/terraform.tfvars
cp terraform/project-b-azure-engineer/example.tfvars \
   terraform/project-b-azure-engineer/terraform.tfvars
```

Edit shared tfvars: `databricks_account_id`, and for personal MSA with existing metastore:

```hcl
create_metastore      = false
existing_metastore_id = "<uuid>"   # databricks account metastores list
```

Metastore discovery:

```fish
databricks account metastores list -o json \
  | jq '.[] | select(.region=="uksouth") | .metastore_id'
```

---

## Phase 3 — Deploy

### Bootstrap remote state

```fish
make bootstrap-azure
# Uncomment backend blocks in shared + engineer main.tf (values from records/bootstrap-azure.outputs.txt)
terraform -chdir=terraform/project-b-azure-shared init -reconfigure
terraform -chdir=terraform/project-b-azure-engineer init -reconfigure
```

### Shared stack

```fish
make apply-b-shared
make b-shared-env-fish | source
# Or:
# set -x METASTORE_ID (terraform -chdir=terraform/project-b-azure-shared output -raw metastore_id)
# set -x ACCESS_CONNECTOR_ID (terraform -chdir=terraform/project-b-azure-shared output -raw access_connector_id)
# set -x ACCESS_CONNECTOR_PRINCIPAL_ID (terraform -chdir=terraform/project-b-azure-shared output -raw access_connector_principal_id)
```

### Engineer stack

```fish
make apply-b ENGINEER=alex \
  METASTORE_ID=$METASTORE_ID \
  ACCESS_CONNECTOR_ID=$ACCESS_CONNECTOR_ID \
  ACCESS_CONNECTOR_PRINCIPAL_ID=$ACCESS_CONNECTOR_PRINCIPAL_ID
```

---

## Phase 4 — Recovery (failed partial apply)

**Do not** delete the workspace or resource group.

### One command (bash script from fish)

```fish
bash scripts/project-b-recover-engineer.sh alex
bash scripts/project-b-recover-engineer.sh alex --delete-warehouse   # if SQL warehouse stuck
```

### Manual fish equivalent

Workspace admin settings path in UI is **Settings → Identity and access → Groups → Manage** — but use CLI instead:

```fish
set WS_URL (az databricks workspace show -g rg-sar-alex -n dbw-sar-alex --query workspaceUrl -o tsv)
set -x DATABRICKS_HOST "https://$WS_URL"
set -x DATABRICKS_AUTH_TYPE azure-cli

databricks groups-v2 list -o json | jq '.[] | {id, displayName}'

for name in sar-alex-data-engineers sar-alex-analysts sar-alex-report-authors
  set ID (databricks groups-v2 list -o json | jq -r ".[] | select(.displayName==\"$name\") | .id")
  if test -n "$ID" -a "$ID" != "null"
    databricks groups-v2 delete $ID; or true
  end
end

make b-shared-env-fish | source
make apply-b ENGINEER=alex \
  METASTORE_ID=$METASTORE_ID \
  ACCESS_CONNECTOR_ID=$ACCESS_CONNECTOR_ID \
  ACCESS_CONNECTOR_PRINCIPAL_ID=$ACCESS_CONNECTOR_PRINCIPAL_ID
```

Delete **workspace-local** groups only. Do **not** delete account-level groups unless re-apply reports duplicate names.

---

## Phase 5 — Handoff (CLI)

Workspace URL:

```fish
az databricks workspace show -g rg-sar-alex -n dbw-sar-alex \
  --query workspaceUrl -o tsv
```

Engineer outputs:

```fish
terraform -chdir=terraform/project-b-azure-engineer workspace select alex
terraform -chdir=terraform/project-b-azure-engineer output
```

Add junior to account group via Databricks account/workspace SCIM API (see [Microsoft manage-groups](https://learn.microsoft.com/en-us/azure/databricks/admin/users-groups/manage-groups)) — not workspace-local groups only.

---

## Helper scripts

| Script | Purpose |
|--------|---------|
| [`scripts/project-b-auth-check.sh`](../../scripts/project-b-auth-check.sh) | Az login, RBAC, providers, tfvars, optional account API |
| [`scripts/project-b-recover-engineer.sh`](../../scripts/project-b-recover-engineer.sh) | Group cleanup + `make apply-b` |

| Make target | Purpose |
|-------------|---------|
| `make b-shared-env` | Bash `export METASTORE_ID=...` |
| `make b-shared-env-fish` | Fish `set -x METASTORE_ID ...` — pipe to `source` |

---

## Related docs

- [Project B deployment stages](./project-b-deployment-stages.md)
- [Project B (Azure) runbook](./project-b-azure-runbook.md) — full reference
- [Personal Azure account setup](./personal-azure-databricks-setup.md) — MSA / first account admin
