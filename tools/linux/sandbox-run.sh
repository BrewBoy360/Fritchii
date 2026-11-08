#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# sandbox-run.sh — run a Lichii/Fritchii binary or AppImage with its own config, data and cache,
# so test builds never touch your normal install (~/.config/eden, ~/.local/share/eden).
#
#   tools/linux/sandbox-run.sh <sandbox-name> <binary-or-AppImage> [emulator args]
#   MH=1  tools/linux/sandbox-run.sh v41 build/bin/lichii       # with MangoHud logging
#   X11=1 tools/linux/sandbox-run.sh v41 build/bin/lichii       # force the X11 backend (xcb)
#
# Environment:
#   SANDBOX_ROOT    where sandboxes live          (default: ${XDG_DATA_HOME:-~/.local/share}/fritchii-sandboxes)
#   MANGOHUD_LOGS   MangoHud CSV output folder    (default: ./mangohud-logs)
#
# A new sandbox is empty: put your own prod.keys/title.keys in <sandbox>/data/eden/keys/ and your
# own firmware via the emulator's menu. This script never copies keys, firmware or saves.
set -euo pipefail
NAME=${1:?usage: sandbox-run.sh <sandbox-name> <binary-or-AppImage> [emulator args]}
APP=${2:?usage: sandbox-run.sh <sandbox-name> <binary-or-AppImage> [emulator args]}
shift 2
APP=$(realpath "$APP")
[[ -f "$APP" ]] || { echo "No such file: $APP"; exit 1; }
[[ -x "$APP" ]] || chmod +x "$APP"
HERE=$(cd "$(dirname "$0")" && pwd)
SANDBOX_ROOT=${SANDBOX_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/fritchii-sandboxes}
ROOT="$SANDBOX_ROOT/$NAME"
# Eglantine names its folders "eglantine"; Lichii/Fritchii keep "eden".
case "${APP,,}" in *eglantine*) DIRNAME=eglantine ;; *) DIRNAME=eden ;; esac

if [[ ! -d "$ROOT" ]]; then
  echo "New sandbox: $ROOT"
  mkdir -p "$ROOT"/{config/$DIRNAME,data/$DIRNAME/keys,cache}
  echo "  put your own keys in $ROOT/data/$DIRNAME/keys/ before the first launch"
fi
# A sandbox copied from another keeps the other's absolute paths in its config and would use the
# other's saves: point them at this sandbox (only lines that name another sandbox are changed).
CONFIG="$ROOT/config/$DIRNAME/qt-config.ini"
if [[ -f "$CONFIG" ]] && grep -qE '^(nand|sdmc|load|dump|tas)_directory=' "$CONFIG"; then
  sed -i -E "s#^((nand|sdmc|load|dump|tas)_directory)=.*/data/$DIRNAME/#\\1=$ROOT/data/$DIRNAME/#" "$CONFIG"
fi

export XDG_CONFIG_HOME="$ROOT/config" XDG_DATA_HOME="$ROOT/data" XDG_CACHE_HOME="$ROOT/cache"
[[ "${X11:-0}" == 1 ]] && export QT_QPA_PLATFORM=xcb
if [[ "${MH:-0}" == 1 ]]; then
  LOGS=$(realpath -m "${MANGOHUD_LOGS:-./mangohud-logs}")
  mkdir -p "$LOGS"
  export MANGOHUD=1 MANGOHUD_CONFIGFILE="$HERE/mangohud.conf" MANGOHUD_CONFIG="output_folder=$LOGS"
fi
echo "Sandbox: $ROOT   MangoHud: ${MH:-0}   X11: ${X11:-0}"
exec "$APP" "$@"
