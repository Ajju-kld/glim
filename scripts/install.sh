#!/usr/bin/env bash
# Installs Glim from its disk image. Builds the disk image first when there isn't one.
#
#   scripts/install.sh                       install into /Applications
#   scripts/install.sh --user                install into ~/Applications (no admin rights needed)
#   scripts/install.sh --destination DIR     install into DIR
#   scripts/install.sh --dmg PATH            install from a disk image you already have
#   scripts/install.sh --open                open Glim when it is installed
set -euo pipefail
cd "$(dirname "$0")/.."

readonly OUTPUT_DIRECTORY="build"
readonly MOUNT_POINT="$OUTPUT_DIRECTORY/dmg-mount"
readonly APP_NAME="Glim.app"
# Glim's default planner model (GlimSettings.defaultPlannerModelName).
readonly PLANNER_MODEL="qwen3-vl:8b"

destination="/Applications"
dmg_path=""
opens_after_install=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) destination="$HOME/Applications"; shift ;;
    --destination)
      [[ $# -ge 2 ]] || { echo "--destination needs a folder" >&2; exit 2; }
      destination="$2"; shift 2 ;;
    --dmg)
      [[ $# -ge 2 ]] || { echo "--dmg needs a path" >&2; exit 2; }
      dmg_path="$2"; shift 2 ;;
    --open) opens_after_install=true; shift ;;
    *) echo "Unknown option: $1 (see the top of scripts/install.sh)" >&2; exit 2 ;;
  esac
done

if [[ -z "$dmg_path" ]]; then
  version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Glim-Info.plist)"
  dmg_path="$OUTPUT_DIRECTORY/Glim-$version.dmg"
  if [[ ! -f "$dmg_path" ]]; then
    scripts/make-dmg.sh
  fi
fi
if [[ ! -f "$dmg_path" ]]; then
  echo "No disk image at $dmg_path" >&2
  exit 1
fi

detach_disk_image() {
  if mount | grep -q " on $PWD/$MOUNT_POINT ("; then
    hdiutil detach -quiet "$MOUNT_POINT" || hdiutil detach -quiet -force "$MOUNT_POINT"
  fi
  # hdiutil removes the mount point it created; a leftover one is empty.
  if [[ -d "$MOUNT_POINT" ]]; then
    rmdir "$MOUNT_POINT"
  fi
}
trap detach_disk_image EXIT

echo "==> Opening $dmg_path"
detach_disk_image
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MOUNT_POINT" "$dmg_path"
codesign --verify --deep --strict "$MOUNT_POINT/$APP_NAME"

mkdir -p "$destination"
if [[ ! -w "$destination" ]]; then
  echo "Can't write to $destination. Use --user to install into ~/Applications instead." >&2
  exit 1
fi
# Quit Glim only when the running copy is the one being replaced.
installed_executable="$(cd "$destination" && pwd)/$APP_NAME/Contents/MacOS/Glim"
for process_identifier in $(pgrep -x Glim || true); do
  if [[ "$(ps -o comm= -p "$process_identifier")" == "$installed_executable" ]]; then
    echo "==> Quitting the running Glim at $destination"
    kill "$process_identifier"
  fi
done

echo "==> Installing into $destination"
rm -rf "${destination:?}/$APP_NAME"
ditto "$MOUNT_POINT/$APP_NAME" "$destination/$APP_NAME"
codesign --verify --deep --strict "$destination/$APP_NAME"
echo "Installed $destination/$APP_NAME"

if ! command -v ollama >/dev/null; then
  echo "Next: install Ollama (brew install ollama; brew services start ollama), then: ollama pull $PLANNER_MODEL"
elif ! ollama list 2>/dev/null | grep -q "^$PLANNER_MODEL "; then
  echo "Next: ollama pull $PLANNER_MODEL"
fi
if [[ "$opens_after_install" == true ]]; then
  open "$destination/$APP_NAME"
  echo "Glim is running: look for the ✦ icon in the menu bar (or hold ⌃⌥V and speak)."
else
  echo "Open it with: open \"$destination/$APP_NAME\""
fi
