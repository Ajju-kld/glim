#!/usr/bin/env bash
# Builds and opens Glim. Always run Glim from its bundle: the bare binary has no Info.plist,
# so macOS would refuse microphone access. Pass --testbed to open the practice app too.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh
if [[ "${1:-}" == "--testbed" ]]; then
  open build/Testbed.app
fi
open build/Glim.app
