#!/usr/bin/env bash
# Prints the code-signing identity Glim's build scripts use: $GLIM_SIGNING_IDENTITY, the first
# "Apple Development" identity in your keychain, or "-" for ad-hoc.
set -euo pipefail

signing_identity="${GLIM_SIGNING_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
  signing_identity="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')"
fi
echo "${signing_identity:--}"
