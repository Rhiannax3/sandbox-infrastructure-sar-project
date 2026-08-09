#!/usr/bin/env bash
# Redeploy the Compose stack on the sandbox EC2 host via SSM SendCommand.
# Usage: ./redeploy.sh <engineer_id> <instance_id> [region]
set -euo pipefail

ENGINEER_ID="${1:?engineer_id required}"
INSTANCE_ID="${2:?instance_id required}"
REGION="${3:-eu-west-2}"
ARTIFACT_BUCKET="sar-${ENGINEER_ID}-artifacts"

echo "Packaging app..."
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p /tmp/sar-app-build
tar -czf /tmp/sar-app-build/app.tar.gz -C "$ROOT/app" compose django-sar-portal keycloak

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --region "$REGION")"
BUCKET="${ARTIFACT_BUCKET}-${ACCOUNT_ID}"

echo "Uploading to s3://${BUCKET}/app/app.tar.gz"
aws s3 cp /tmp/sar-app-build/app.tar.gz "s3://${BUCKET}/app/app.tar.gz" --region "$REGION"

echo "Sending SSM redeploy command to ${INSTANCE_ID}"
COMMAND_ID="$(aws ssm send-command \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --comment "Redeploy SAR sandbox app for ${ENGINEER_ID}" \
  --parameters 'commands=["set -euo pipefail","APP_DIR=/opt/sar-sandbox","aws s3 cp s3://'"${BUCKET}"'/app/app.tar.gz /tmp/app.tar.gz","tar -xzf /tmp/app.tar.gz -C $APP_DIR","cd $APP_DIR/compose","docker compose --env-file $APP_DIR/.env pull || true","docker compose --env-file $APP_DIR/.env up -d --build"]' \
  --query 'Command.CommandId' \
  --output text)"

echo "CommandId=${COMMAND_ID}"
echo "Waiting for completion..."
aws ssm wait command-executed --region "$REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" || true
aws ssm get-command-invocation --region "$REGION" --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
  --output json
