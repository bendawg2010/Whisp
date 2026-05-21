#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi

echo "Generating Whisp.xcodeproj..."
xcodegen generate

echo "Building Whisp.app..."
xcodebuild \
  -project Whisp.xcodeproj \
  -scheme Whisp \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$ROOT/build/DerivedData/Build/Products/Release/Whisp.app"
echo ""
echo "Built: $APP_PATH"

