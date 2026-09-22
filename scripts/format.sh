#!/usr/bin/env bash
# Rewrites Sources and Tests in the project's house style (.swift-format).
set -euo pipefail
cd "$(dirname "$0")/.."
swift format format --in-place --recursive Sources Tests
