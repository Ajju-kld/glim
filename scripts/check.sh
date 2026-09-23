#!/usr/bin/env bash
# Runs every quality gate the project requires. A non-zero exit means the build is red.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift build"
swift build

echo "==> swift test"
swift test

readonly LAYA_PYTHON="services/laya/.venv/bin/python"
if [[ -x "$LAYA_PYTHON" ]]; then
  echo "==> Laya training tests"
  (cd services/laya && ../../"$LAYA_PYTHON" -m unittest discover -s training/tests -t .)
else
  echo "==> Laya training tests skipped: run scripts/start-laya.sh once to install Laya"
fi

echo "==> swift format lint (strict)"
swift format lint --strict --recursive Sources Tests

echo "All gates passed."
