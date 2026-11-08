#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# perf-thread.sh — profile one thread of a running Lichii (default: the GPU front thread "GPU").
#   tools/linux/perf-thread.sh <label>                     e.g. tools/linux/perf-thread.sh door-move
#   THREAD=GPUBack tools/linux/perf-thread.sh back-door-move
# Environment: LICHII_BIN (default build/bin/lichii), OUT_DIR (default ./perf-data), SECS (20).
# Needs `sudo sysctl kernel.perf_event_paranoid=1 kernel.kptr_restrict=0` (until reboot).
# Writes <label>.data plus <label>.maps (the process's memory map, to attribute libc, driver and
# JIT addresses later). --proc-map-timeout is raised because Lichii has ~100k memory mappings:
# with perf's default 500 ms it stops reading them before libc and the stacks end there.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LABEL=${1:?usage: perf-thread.sh <label>}
BIN=$(realpath "${LICHII_BIN:-$REPO/build/bin/lichii}")
OUT_DIR=$(realpath -m "${OUT_DIR:-./perf-data}")
SECS=${SECS:-20}
THREAD=${THREAD:-GPU}
OUT=$OUT_DIR/$LABEL.data
mkdir -p "$OUT_DIR"
par=$(cat /proc/sys/kernel/perf_event_paranoid)
(( par <= 1 )) || { echo "perf_event_paranoid is $par; run: sudo sysctl kernel.perf_event_paranoid=1 kernel.kptr_restrict=0"; exit 1; }
[[ -e "$OUT" ]] && { echo "$OUT already exists; pick another label"; exit 1; }
PID=""; for p in $(pgrep -x lichii); do [[ "$(readlink /proc/$p/exe)" == "$BIN" ]] && PID=$p; done
[[ -n "$PID" ]] || { echo "No running lichii from $BIN"; exit 1; }
TID=""; for t in /proc/$PID/task/*; do [[ "$(cat $t/comm)" == "$THREAD" ]] && TID=${t##*/}; done
[[ -n "$TID" ]] || { echo "No '$THREAD' thread yet in PID $PID: load a game first"; exit 1; }
cp /proc/$PID/maps "${OUT%.data}.maps"
echo "lichii $PID, $THREAD thread TID $TID. Recording starts in 5 s, lasts ${SECS} s."
for i in 5 4 3 2 1; do printf '%s ' $i; sleep 1; done; echo
perf record -q -t "$TID" -F 999 --call-graph dwarf,32768 --proc-map-timeout=60000 -o "$OUT" -- sleep "$SECS" || true
echo "Saved $OUT ($(du -h "$OUT" | cut -f1)). Read with: perf report -i $OUT --no-children"
