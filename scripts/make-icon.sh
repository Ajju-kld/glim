#!/usr/bin/env bash
# Renders Resources/AppIcon/glim-icon.svg into Resources/Glim.icns.
set -euo pipefail
cd "$(dirname "$0")/.."

readonly SOURCE_SVG="Resources/AppIcon/glim-icon.svg"
readonly ICONSET_DIRECTORY="build/Glim.iconset"
readonly OUTPUT_ICNS="Resources/Glim.icns"

rm -rf "$ICONSET_DIRECTORY"
swift scripts/render-icon.swift "$SOURCE_SVG" "$ICONSET_DIRECTORY"
iconutil -c icns "$ICONSET_DIRECTORY" -o "$OUTPUT_ICNS"
echo "Wrote $OUTPUT_ICNS"
