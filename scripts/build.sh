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

echo "Ad-hoc signing Whisp.app and embedded Sparkle code..."
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
  codesign --force --sign - --timestamp=none "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
  codesign --force --sign - --timestamp=none "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
  codesign --force --sign - --timestamp=none "$SPARKLE_FRAMEWORK/Versions/B/Updater.app"
  codesign --force --sign - --timestamp=none "$SPARKLE_FRAMEWORK"
fi

codesign --force --sign - --timestamp=none \
  --entitlements "$ROOT/App/Whisp.entitlements" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo ""
echo "Built: $APP_PATH"
