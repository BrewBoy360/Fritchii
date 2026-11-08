#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# affinity.sh — live CPU affinity of a running Lichii's threads, grouped by thread name.
#   tools/linux/affinity.sh [binary]      default: $LICHII_BIN, else build/bin/lichii in this repo
# Shows GPU / GPUBack / CPUCore_* / VkPipeline* / ImageTranscode first, then a count of the
# other threads per affinity. Reads /proc only.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
BIN=$(realpath "${1:-${LICHII_BIN:-$REPO/build/bin/lichii}}")
PID=""
for p in $(pgrep -x lichii); do [[ "$(readlink /proc/$p/exe)" == "$BIN" ]] && PID=$p; done
[[ -n "$PID" ]] || { echo "No running lichii from $BIN"; exit 1; }
echo "lichii $PID ($BIN), process affinity: $(grep Cpus_allowed_list /proc/$PID/status | cut -f2)"
declare -A groups
while read -r tid; do
    name=$(cat /proc/$PID/task/$tid/comm 2>/dev/null) || continue
    cpus=$(grep Cpus_allowed_list /proc/$PID/task/$tid/status 2>/dev/null | cut -f2) || continue
    case "$name" in
        GPU|GPUBack|CPUCore_*|VkPipeline*|ImageTranscode*)
            printf '  %-16s tid %-7s cpus %s\n' "$name" "$tid" "$cpus" ;;
        *) groups["$cpus"]=$(( ${groups["$cpus"]:-0} + 1 )) ;;
    esac
done < <(ls /proc/$PID/task | sort -n)
echo "other threads by affinity:"
for cpus in "${!groups[@]}"; do printf '  %3d threads  cpus %s\n' "${groups[$cpus]}" "$cpus"; done
