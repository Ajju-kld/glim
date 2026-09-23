#!/usr/bin/env bash
# Packages Glim into build/Glim-<version>.dmg. Open it and drag Glim onto Applications, or run
# scripts/install.sh. The disk image is signed with the same identity as the app.
#
#   scripts/make-dmg.sh               build the app, then the disk image
#   scripts/make-dmg.sh --skip-build  package the build/Glim.app that is already there
set -euo pipefail
cd "$(dirname "$0")/.."

readonly OUTPUT_DIRECTORY="build"
readonly GLIM_APP="$OUTPUT_DIRECTORY/Glim.app"
readonly STAGING_DIRECTORY="$OUTPUT_DIRECTORY/dmg-staging"
readonly VOLUME_NAME="Glim"
version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Glim-Info.plist)"
readonly DMG_PATH="$OUTPUT_DIRECTORY/Glim-$version.dmg"

case "${1:-}" in
  --skip-build) ;;
  "") scripts/build-app.sh ;;
  *) echo "Unknown option: $1 (use --skip-build or nothing)" >&2; exit 2 ;;
esac
if [[ ! -d "$GLIM_APP" ]]; then
  echo "No $GLIM_APP to package. Run scripts/make-dmg.sh without --skip-build." >&2
  exit 1
fi

echo "==> Staging the disk image contents"
rm -rf "$STAGING_DIRECTORY"
mkdir -p "$STAGING_DIRECTORY"
ditto "$GLIM_APP" "$STAGING_DIRECTORY/Glim.app"
# The drag target shown next to Glim in the window.
ln -s /Applications "$STAGING_DIRECTORY/Applications"

echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create -quiet -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIRECTORY" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG_PATH"
rm -rf "$STAGING_DIRECTORY"

signing_identity="$(scripts/signing-identity.sh)"
echo "==> Signing the disk image with: $signing_identity"
codesign --force --timestamp=none --sign "$signing_identity" "$DMG_PATH"

echo "==> Verifying"
hdiutil verify -quiet "$DMG_PATH"
codesign --verify --strict "$DMG_PATH"
echo "Built $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1 | tr -d ' '))"
