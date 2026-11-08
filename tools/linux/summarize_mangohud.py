#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Summarize MangoHud CSV logs: avg FPS, 1% low, min FPS, worst frametime, GPU/CPU load.

Usage:
  summarize_mangohud.py                      # newest log in the logs folder
  summarize_mangohud.py FILE.csv [FILE2.csv] # specific logs (compare side by side)
  summarize_mangohud.py --all                # every log, oldest first

The log folder is MANGOHUD_LOGS (default: ./mangohud-logs, as sandbox-run.sh writes them).
"""
import csv
import glob
import os
import statistics
import sys

LOG_DIR = os.environ.get("MANGOHUD_LOGS", "mangohud-logs")


def read_log(path):
    with open(path, newline="") as f:
        rows = list(csv.reader(f))
    # MangoHud writes system-info lines first, then a header row that starts with "fps".
    for i, row in enumerate(rows):
        if row and row[0].strip().lower() == "fps":
            header = [c.strip().lower() for c in row]
            data = [r for r in rows[i + 1:] if len(r) == len(header)]
            return header, data
    raise ValueError(f"{path}: no 'fps' header row found")


def column(header, data, name):
    if name not in header:
        return []
    idx = header.index(name)
    out = []
    for r in data:
        try:
            out.append(float(r[idx]))
        except ValueError:
            pass
    return out


def summarize(path):
    header, data = read_log(path)
    ft = [x for x in column(header, data, "frametime") if x > 0]  # ms per frame
    if not ft:
        raise ValueError(f"{path}: no frametime data")
    ft_sorted = sorted(ft, reverse=True)
    worst_1pct = ft_sorted[: max(1, len(ft) // 100)]
    total_s = sum(ft) / 1000
    gpu = column(header, data, "gpu_load")
    cpu = column(header, data, "cpu_load")
    return {
        "log": os.path.basename(path),
        "frames": len(ft),
        "seconds": round(total_s, 1),
        "avg_fps": round(len(ft) / total_s, 1),
        "1%_low_fps": round(1000 / statistics.mean(worst_1pct), 1),
        "min_fps": round(1000 / ft_sorted[0], 1),
        "max_ft_ms": round(ft_sorted[0], 1),
        "frames_over_40ms": sum(1 for x in ft if x > 40),
        "gpu_load_%": round(statistics.mean(gpu), 1) if gpu else None,
        "cpu_load_%": round(statistics.mean(cpu), 1) if cpu else None,
    }


def main(argv):
    if argv and argv[0] == "--all":
        paths = sorted(glob.glob(os.path.join(LOG_DIR, "*.csv")), key=os.path.getmtime)
    elif argv:
        paths = argv
    else:
        paths = sorted(glob.glob(os.path.join(LOG_DIR, "*.csv")), key=os.path.getmtime)[-1:]
    paths = [p for p in paths if not p.endswith("_summary.csv")]
    if not paths:
        sys.exit(f"No logs found in {LOG_DIR}. Press Shift_L+F2 in game to record one.")
    results = []
    for p in paths:
        try:
            results.append(summarize(p))
        except ValueError as e:
            print(f"skip: {e}", file=sys.stderr)
    if not results:
        sys.exit(1)
    keys = list(results[0].keys())
    widths = {k: max(len(k), *(len(str(r[k])) for r in results)) for k in keys}
    print("  ".join(k.ljust(widths[k]) for k in keys))
    for r in results:
        print("  ".join(str(r[k]).ljust(widths[k]) for k in keys))


if __name__ == "__main__":
    main(sys.argv[1:])
