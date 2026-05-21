#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_APP_PATH="${ROOT}/build/DerivedData/Build/Products/Release/Whisp.app"
APP_PATH="${1:-${DEFAULT_APP_PATH}}"
DMG_PATH="${2:-${ROOT}/build/Whisp.dmg}"

if [[ "${APP_PATH}" != /* ]]; then
  APP_PATH="${ROOT}/${APP_PATH}"
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Whisp.app not found at ${APP_PATH}. Run scripts/build.sh first." >&2
  exit 1
fi

BUILD_DIR="${ROOT}/build"
STAGING_DIR="${BUILD_DIR}/dmg-staging"

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "Whisp" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "${DMG_PATH}"

echo "DMG built: ${DMG_PATH}"

