#!/usr/bin/env bash
# Package this directory (handler, extra .py modules, contracts/, dependencies)
# and upload it to an existing Lambda function.
#
# Usage:
#   ./publish.sh <function-name> [region]
#   ./publish.sh sar-alex-lambda eu-west-2
set -euo pipefail

FUNCTION_NAME="${1:?Usage: $0 <function-name> [region]}"
REGION="${2:-eu-west-2}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/.build"
ZIP="$ROOT/function.zip"

rm -rf "$BUILD" "$ZIP"
mkdir -p "$BUILD"

shopt -s nullglob
cp -a "$ROOT"/*.py "$BUILD/"
cp -a "$ROOT/contracts" "$BUILD/contracts"
shopt -u nullglob

if [[ -s "$ROOT/requirements.txt" ]]; then
  python3 -m pip install --quiet -r "$ROOT/requirements.txt" -t "$BUILD"
fi

(
  cd "$BUILD"
  zip -qr "$ZIP" . -x '*.pyc' -x '__pycache__/*'
)

aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file "fileb://$ZIP" \
  --region "$REGION"

echo "Published $ZIP -> $FUNCTION_NAME ($REGION)"
