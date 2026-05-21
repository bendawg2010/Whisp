#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <version> '<release-notes-html>'" >&2
  exit 1
fi

VERSION="$1"
NOTES_HTML="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_NUMBER="${BUILD_NUMBER:-$(echo "$VERSION" | tr -d '.')}"
echo "Releasing Whisp v${VERSION} (build ${BUILD_NUMBER})"

sed -i '' -E "s/^([[:space:]]*MARKETING_VERSION:[[:space:]]*).*$/\1\"${VERSION}\"/" project.yml
sed -i '' -E "s/^([[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*).*$/\1\"${BUILD_NUMBER}\"/" project.yml

"$ROOT/scripts/build.sh"
"$ROOT/scripts/build-dmg.sh"

DMG_PATH="$ROOT/build/Whisp.dmg"
DMG_SIZE="$(stat -f%z "$DMG_PATH")"
SIGN_UPDATE="$ROOT/scripts/sparkle/bin/sign_update"
ED_SIGNATURE=""

if [[ -x "$SIGN_UPDATE" ]]; then
  SIGN_OUTPUT="$("$SIGN_UPDATE" "$DMG_PATH" || true)"
  ED_SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -nE 's/.*sparkle:edSignature="([^"]+)".*/\1/p')"
fi

PUB_DATE="$(LC_TIME=en_US.UTF-8 date -u +"%a, %d %b %Y %H:%M:%S +0000")"
DOWNLOAD_URL="https://whisp-buz.pages.dev/Whisp.dmg"
ENCLOSURE_ATTRS="url=\"${DOWNLOAD_URL}\" sparkle:version=\"${BUILD_NUMBER}\" sparkle:shortVersionString=\"${VERSION}\" length=\"${DMG_SIZE}\" type=\"application/octet-stream\""
if [[ -n "$ED_SIGNATURE" ]]; then
  ENCLOSURE_ATTRS+=" sparkle:edSignature=\"${ED_SIGNATURE}\""
fi

NEW_ITEM=$(cat <<EOF
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <description><![CDATA[${NOTES_HTML}]]></description>
      <enclosure ${ENCLOSURE_ATTRS} />
    </item>
EOF
)

TMP_APPCAST="$(mktemp -t whisp-appcast)"
export NEW_ITEM
awk '
  /<\/channel>/ && !done { print ENVIRON["NEW_ITEM"]; done=1 }
  { print }
' "$ROOT/website/appcast.xml" > "$TMP_APPCAST"
mv "$TMP_APPCAST" "$ROOT/website/appcast.xml"

cp "$DMG_PATH" "$ROOT/website/Whisp.dmg"
echo "Copied newly built DMG to website directory: website/Whisp.dmg"

if command -v gh >/dev/null 2>&1; then
  gh release create "v${VERSION}" "$DMG_PATH" \
    --title "v${VERSION}" \
    --notes "$NOTES_HTML"
else
  echo "gh CLI not found; skipping GitHub release creation."
fi

echo "Whisp v${VERSION} release artifact: ${DMG_PATH}"

