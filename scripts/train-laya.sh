#!/usr/bin/env bash
# Scores Laya on the reviewed examples from Glim's Laya Training page, trains a new checkpoint
# on this Mac, and promotes it only if it catches more wrong picks without more false alarms.
#   scripts/train-laya.sh               train (needs 200 reviewed examples from 5 apps)
#   scripts/train-laya.sh --score-only  just score the active model
#   scripts/train-laya.sh --rollback    go back to the published model
# Nothing leaves the Mac: the model loads from services/laya/model-cache with the hub offline.
set -euo pipefail
readonly LAYA_DIRECTORY="$(cd "$(dirname "$0")/../services/laya" && pwd)"

if [[ ! -x "$LAYA_DIRECTORY/.venv/bin/python" ]]; then
  echo "Laya isn't installed yet: run scripts/start-laya.sh once first." >&2
  exit 1
fi
export HF_HOME="$LAYA_DIRECTORY/model-cache"
export HF_HUB_OFFLINE=1
# Stays in the caller's folder, so relative --examples paths work.
PYTHONPATH="$LAYA_DIRECTORY" exec "$LAYA_DIRECTORY/.venv/bin/python" -m training.train "$@"
