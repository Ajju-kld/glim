#!/usr/bin/env bash
# Runs every quality gate the project requires. A non-zero exit means the build is red.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift build"
swift build

echo "==> swift test"
swift test

echo "==> swift format lint (strict)"
swift format lint --strict --recursive Sources Tests

echo "All gates passed."
