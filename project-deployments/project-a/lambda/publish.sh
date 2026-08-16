#!/usr/bin/env bash
# Package this directory (handler, extra .py modules, contracts/, dependencies)
# and upload it to an existing Lambda function.
#
# Packaging (pip install jsonschema) always runs on the sandbox EC2 host, which
# has Python. From a laptop this script only uploads source with the AWS CLI
# and asks the host to build the zip — no local Python required.
#
# Usage (laptop, AWS CLI + junior policy):
#   ENGINEER_ID=alex ./publish.sh sar-alex-lambda
#   ENGINEER_ID=alex ./publish.sh sar-alex-lambda eu-west-2
#
# Usage (already on the host via SSM):
#   ./publish.sh sar-alex-lambda
set -euo pipefail

FUNCTION_NAME="${1:?Usage: ENGINEER_ID=<you> $0 <function-name> [region]}"
REGION="${2:-eu-west-2}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/.build"
ZIP="$ROOT/function.zip"

on_ec2() {
  # Instant on the sandbox host; do not probe 169.254 from a laptop (curl can hang for minutes).
  [[ -f /opt/sar-sandbox/.env ]]
}

ensure_pip() {
  if python3 -m pip --version >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing python3-pip on the sandbox host..."
  sudo dnf install -y python3-pip zip >/dev/null
}

lambda_runtime() {
  aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query Runtime \
    --output text
}

lambda_arch() {
  aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --query 'Architectures[0]' \
    --output text
}

sync_python_deps() {
  local req="$ROOT/requirements.txt"
  local deps="$ROOT/.deps"
  local hash_file="$deps/.requirements.sha256"
  local req_hash="" runtime arch pyver docker_platform pip_platform cache_key

  [[ -s "$req" ]] || return 0

  runtime="$(lambda_runtime)"
  arch="$(lambda_arch)"
  pyver="${runtime#python}"
  docker_platform="linux/amd64"
  pip_platform="manylinux2014_x86_64"
  if [[ "$arch" == "arm64" ]]; then
    docker_platform="linux/arm64"
    pip_platform="manylinux2014_aarch64"
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    req_hash="$(sha256sum "$req" | awk '{print $1}')"
  else
    req_hash="$(shasum -a 256 "$req" | awk '{print $1}')"
  fi
  cache_key="${runtime}-${arch}-${req_hash}"

  if [[ -f "$hash_file" && "$(cat "$hash_file")" == "$cache_key" && -d "$deps" ]]; then
    echo "Reusing cached Python dependencies in $deps ($runtime / $arch)"
    return 0
  fi

  echo "Installing Python dependencies for ${runtime} (${arch})..."
  rm -rf "$deps"
  mkdir -p "$deps"

  if sudo docker run --rm --platform "$docker_platform" \
    -v "$deps":/var/task \
    -v "$req":/requirements.txt:ro \
    "public.ecr.aws/lambda/python:${pyver}" \
    pip install --disable-pip-version-check -r /requirements.txt -t /var/task
  then
    printf '%s\n' "$cache_key" >"$hash_file"
    return 0
  fi

  echo "Docker Lambda image unavailable; installing Lambda-compatible wheels with pip..."
  ensure_pip
  python3 -m pip install \
    --disable-pip-version-check \
    --platform "$pip_platform" \
    --python-version "$pyver" \
    --implementation cp \
    --only-binary=:all: \
    --upgrade \
    -r "$req" \
    -t "$deps"
  printf '%s\n' "$cache_key" >"$hash_file"
}

package_on_host() {
  rm -rf "$BUILD" "$ZIP"
  mkdir -p "$BUILD"

  shopt -s nullglob
  if [[ ! -f "$ROOT/lambda_function.py" ]]; then
    echo "Copy example_lambda_function.py to lambda_function.py, then retry." >&2
    exit 1
  fi

  sync_python_deps
  if [[ -d "$ROOT/.deps" ]]; then
    cp -a "$ROOT/.deps"/. "$BUILD/"
    rm -f "$BUILD/.requirements.sha256"
  fi

  for src in "$ROOT"/*.py; do
    [[ "$(basename "$src")" == example_lambda_function.py ]] && continue
    cp -a "$src" "$BUILD/"
  done
  cp -a "$ROOT/contracts" "$BUILD/contracts"
  shopt -u nullglob

  (
    cd "$BUILD"
    if command -v zip >/dev/null 2>&1; then
      zip -qr "$ZIP" . -x '*.pyc' -x '__pycache__/*'
    else
      python3 - "$ZIP" <<'PY'
import pathlib, shutil, sys
shutil.make_archive(str(pathlib.Path(sys.argv[1]).with_suffix("")), "zip", ".")
PY
    fi
  )

  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP" \
    --region "$REGION"

  echo "Published $ZIP -> $FUNCTION_NAME ($REGION) from the sandbox host"
}

if on_ec2; then
  package_on_host
  exit 0
fi

ENGINEER_ID="${ENGINEER_ID:-}"
if [[ -z "$ENGINEER_ID" ]]; then
  echo "Set ENGINEER_ID to your sandbox id (the bit in sar-<you>-…)." >&2
  echo "Example:  ENGINEER_ID=alex $0 $FUNCTION_NAME $REGION" >&2
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --region "$REGION")"
BUCKET="sar-${ENGINEER_ID}-artifacts-${ACCOUNT_ID}"
INSTANCE_ID="$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=sar-${ENGINEER_ID}-sandbox-host" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)"

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "No running host named sar-${ENGINEER_ID}-sandbox-host in ${REGION}." >&2
  echo "Ask your mentor to start the instance, then retry." >&2
  exit 1
fi

SRC_TAR="$(mktemp "${TMPDIR:-/tmp}/lambda-src.XXXXXX.tar.gz")"
SSM_INPUT="$(mktemp "${TMPDIR:-/tmp}/ssm-publish.XXXXXX.json")"
trap 'rm -f "$SRC_TAR" "$SSM_INPUT"' EXIT

tar -C "$ROOT" \
  --exclude .build \
  --exclude .deps \
  --exclude function.zip \
  --exclude __pycache__ \
  --exclude '*.pyc' \
  -czf "$SRC_TAR" .

echo "Uploading source to s3://${BUCKET}/lambda/src.tar.gz"
aws s3 cp "$SRC_TAR" "s3://${BUCKET}/lambda/src.tar.gz" --region "$REGION"

cat > "$SSM_INPUT" <<JSON
{
  "InstanceIds": ["${INSTANCE_ID}"],
  "DocumentName": "AWS-RunShellScript",
  "Comment": "Publish Lambda ${FUNCTION_NAME} for ${ENGINEER_ID}",
  "Parameters": {
    "commands": [
      "set -euo pipefail",
      "aws s3 cp s3://${BUCKET}/lambda/src.tar.gz /tmp/lambda-src.tar.gz --region ${REGION}",
      "mkdir -p /opt/sar-sandbox/lambda",
      "tar -xzf /tmp/lambda-src.tar.gz -C /opt/sar-sandbox/lambda",
      "chmod +x /opt/sar-sandbox/lambda/publish.sh",
      "/opt/sar-sandbox/lambda/publish.sh ${FUNCTION_NAME} ${REGION}"
    ]
  }
}
JSON

echo "Asking sandbox host ${INSTANCE_ID} to install deps and update ${FUNCTION_NAME}"
COMMAND_ID="$(aws ssm send-command \
  --region "$REGION" \
  --cli-input-json "file://${SSM_INPUT}" \
  --query 'Command.CommandId' \
  --output text)"

echo "CommandId=${COMMAND_ID}"
aws ssm wait command-executed \
  --region "$REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" || true
aws ssm get-command-invocation \
  --region "$REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
  --output json
