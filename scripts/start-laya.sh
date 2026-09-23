#!/usr/bin/env bash
# Installs (on first run) and starts the local Laya decision service on 127.0.0.1:8791.
# Source, virtual environment and model cache all live inside services/laya/.
# Review services/laya/README.md before the first run.
set -euo pipefail
cd "$(dirname "$0")/.."

readonly LAYA_REPOSITORY="https://github.com/ChenneyZhuang/laya-browser-agent.git"
# Pinned commit reviewed in services/laya/README.md. Change it only after re-reviewing.
readonly LAYA_PINNED_COMMIT="bafba5975cc1bdb0138f3baa5330108afa0f9055"
readonly SERVICE_HOST="127.0.0.1"
readonly SERVICE_PORT="8791"
readonly SERVICE_DIRECTORY="services/laya"
readonly SOURCE_DIRECTORY="$SERVICE_DIRECTORY/src"
readonly VIRTUAL_ENVIRONMENT="$SERVICE_DIRECTORY/.venv"
readonly MODEL_CACHE="$SERVICE_DIRECTORY/model-cache"
readonly PYTHON_EXECUTABLE="${LAYA_PYTHON:-/opt/homebrew/bin/python3}"

if [[ ! -d "$SOURCE_DIRECTORY/.git" ]]; then
  echo "==> Cloning laya-browser-agent into $SOURCE_DIRECTORY"
  git clone --quiet "$LAYA_REPOSITORY" "$SOURCE_DIRECTORY"
fi
git -C "$SOURCE_DIRECTORY" fetch --quiet origin
git -C "$SOURCE_DIRECTORY" checkout --quiet "$LAYA_PINNED_COMMIT"
checked_out_commit="$(git -C "$SOURCE_DIRECTORY" rev-parse HEAD)"
if [[ "$checked_out_commit" != "$LAYA_PINNED_COMMIT" ]]; then
  echo "Refusing to start: checked out $checked_out_commit, expected $LAYA_PINNED_COMMIT" >&2
  exit 1
fi

if [[ ! -x "$VIRTUAL_ENVIRONMENT/bin/localdecide" ]]; then
  echo "==> Creating the virtual environment in $VIRTUAL_ENVIRONMENT"
  "$PYTHON_EXECUTABLE" -m venv "$VIRTUAL_ENVIRONMENT"
  "$VIRTUAL_ENVIRONMENT/bin/pip" install --quiet --upgrade pip
  "$VIRTUAL_ENVIRONMENT/bin/pip" install --quiet -e "$SOURCE_DIRECTORY[mlx]"
fi

export HF_HOME="$PWD/$MODEL_CACHE"
export LOCALDECIDE_HOST="$SERVICE_HOST"
echo "==> Starting Laya on http://$SERVICE_HOST:$SERVICE_PORT (model cache: $MODEL_CACHE)"
export LOCALDECIDE_PORT="$SERVICE_PORT"
# glim_serve.py runs localdecide on the checkpoint scripts/train-laya.sh promoted, if any.
cd "$SERVICE_DIRECTORY"
exec "../../$VIRTUAL_ENVIRONMENT/bin/python" glim_serve.py
