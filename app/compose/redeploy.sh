#!/usr/bin/env bash
# Redeploy the Compose stack on the sandbox EC2 host via SSM SendCommand.
# Packages source only (no local Docker). The host runs `docker compose ... --build`.
# Usage: ./redeploy.sh <engineer_id> <instance_id> [region]
set -euo pipefail

ENGINEER_ID="${1:?engineer_id required}"
INSTANCE_ID="${2:?instance_id required}"
REGION="${3:-eu-west-2}"
ARTIFACT_BUCKET="sar-${ENGINEER_ID}-artifacts"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAGE_DIR="/tmp/sar-app-stage-$$"
ZIP_PATH="/tmp/sar-app-build/app.zip"

echo "Staging app (no Docker)..."
bash "$ROOT/scripts/stage-app-artifact.sh" "$STAGE_DIR"
mkdir -p /tmp/sar-app-build
rm -f "$ZIP_PATH"
python3 - "$STAGE_DIR" "$ZIP_PATH" <<'PY'
import sys, shutil
from pathlib import Path
stage, out = Path(sys.argv[1]), Path(sys.argv[2])
out.parent.mkdir(parents=True, exist_ok=True)
# make_archive adds .zip; strip if already present
base = str(out.with_suffix(""))
shutil.make_archive(base, "zip", root_dir=stage)
PY
rm -rf "$STAGE_DIR"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --region "$REGION")"
BUCKET="${ARTIFACT_BUCKET}-${ACCOUNT_ID}"

echo "Uploading to s3://${BUCKET}/app/app.zip"
aws s3 cp "$ZIP_PATH" "s3://${BUCKET}/app/app.zip" --region "$REGION"

echo "Sending SSM redeploy command to ${INSTANCE_ID}"
COMMAND_ID="$(aws ssm send-command \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --comment "Redeploy SAR sandbox app for ${ENGINEER_ID}" \
  --parameters 'commands=["set -euo pipefail","APP_DIR=/opt/sar-sandbox","aws s3 cp s3://'"${BUCKET}"'/app/app.zip /tmp/app.zip","unzip -o /tmp/app.zip -d $APP_DIR","cd $APP_DIR/compose","docker compose --env-file $APP_DIR/.env pull || true","docker compose --env-file $APP_DIR/.env up -d --build"]' \
  --query 'Command.CommandId' \
  --output text)"

echo "CommandId=${COMMAND_ID}"
echo "Waiting for completion..."
aws ssm wait command-executed --region "$REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" || true
aws ssm get-command-invocation --region "$REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
  --output json
