#!/usr/bin/env bash
# Renders the icon sources in Resources/AppIcon into .icns files in Resources/.
set -euo pipefail
cd "$(dirname "$0")/.."

render_icon() {
  local source_svg="$1"
  local output_icns="$2"
  local iconset_directory="build/$(basename "$output_icns" .icns).iconset"
  rm -rf "$iconset_directory"
  swift scripts/render-icon.swift "$source_svg" "$iconset_directory"
  iconutil -c icns "$iconset_directory" -o "$output_icns"
  echo "Wrote $output_icns"
}

render_icon Resources/AppIcon/glim-icon.svg Resources/Glim.icns
render_icon Resources/AppIcon/testbed-icon.svg Resources/Testbed.icns
