#!/usr/bin/env bash
# Builds Glim.app (with the GlimWatchdog helper inside) and Testbed.app into build/, and signs
# them with Hardened Runtime.
#
# Signing identity, in order: $GLIM_SIGNING_IDENTITY, the first "Apple Development" identity in
# your keychain, or ad-hoc ("-"). A stable identity keeps macOS permission grants across rebuilds
# and lets Testbed pass Glim's signature check (ad-hoc builds are capped at read-only).
# Force ad-hoc with: GLIM_SIGNING_IDENTITY=- scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

readonly CONFIGURATION="${GLIM_CONFIGURATION:-release}"
readonly OUTPUT_DIRECTORY="build"
readonly GLIM_APP="$OUTPUT_DIRECTORY/Glim.app"
readonly TESTBED_APP="$OUTPUT_DIRECTORY/Testbed.app"
readonly WATCHDOG_IDENTIFIER="dev.straxs.Glim.Watchdog"

signing_identity="${GLIM_SIGNING_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
  signing_identity="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')"
fi
if [[ -z "$signing_identity" ]]; then
  signing_identity="-"
fi

echo "==> Building ($CONFIGURATION)"
for product in Glim GlimWatchdog Testbed; do
  swift build -c "$CONFIGURATION" --product "$product"
done
binary_directory="$(swift build -c "$CONFIGURATION" --show-bin-path)"

echo "==> Assembling $GLIM_APP"
rm -rf "$GLIM_APP" "$TESTBED_APP"
mkdir -p "$GLIM_APP/Contents/MacOS" "$GLIM_APP/Contents/Helpers" "$GLIM_APP/Contents/Resources"
cp "$binary_directory/Glim" "$GLIM_APP/Contents/MacOS/Glim"
cp "$binary_directory/GlimWatchdog" "$GLIM_APP/Contents/Helpers/GlimWatchdog"
cp Resources/Glim-Info.plist "$GLIM_APP/Contents/Info.plist"

echo "==> Assembling $TESTBED_APP"
mkdir -p "$TESTBED_APP/Contents/MacOS"
cp "$binary_directory/Testbed" "$TESTBED_APP/Contents/MacOS/Testbed"
cp Resources/Testbed-Info.plist "$TESTBED_APP/Contents/Info.plist"

echo "==> Signing with: $signing_identity"
# Inside-out: the helper first, then the app that contains it.
codesign --force --options runtime --timestamp=none --identifier "$WATCHDOG_IDENTIFIER" \
  --sign "$signing_identity" "$GLIM_APP/Contents/Helpers/GlimWatchdog"
codesign --force --options runtime --timestamp=none --entitlements Resources/Glim.entitlements \
  --sign "$signing_identity" "$GLIM_APP"
codesign --force --options runtime --timestamp=none --sign "$signing_identity" "$TESTBED_APP"

echo "==> Verifying"
codesign --verify --deep --strict "$GLIM_APP"
codesign --verify --deep --strict "$TESTBED_APP"
echo "Built $GLIM_APP and $TESTBED_APP"
