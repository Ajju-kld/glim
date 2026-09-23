#!/usr/bin/env bash
# Builds and opens Glim. Always run Glim from its bundle: the bare binary has no Info.plist,
# so macOS would refuse microphone access. Pass --testbed to open the practice app too.
set -euo pipefail
cd "$(dirname "$0")/.."

# Quit copies that are already running, so the fresh build is the one that opens.
for app_name in Glim Testbed; do
  if pgrep -x "$app_name" >/dev/null; then
    pkill -x "$app_name"
  fi
done

scripts/build-app.sh
if [[ "${1:-}" == "--testbed" ]]; then
  open build/Testbed.app
fi
open build/Glim.app
echo "Glim is running: look for the ✦ icon in the menu bar (or hold ⌃⌥V and speak)."
