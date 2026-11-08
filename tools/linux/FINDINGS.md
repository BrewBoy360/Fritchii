<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Ocarina of Time on Linux: profiling findings (sanitized summary for contributors)

From one machine (Ryzen 7 2700X, RTX 3060, Kubuntu 26.04 / XWayland), 2026-11-07/08. The scene is Link's house (moving, rotating) plus a Kokiri Forest route, docked, 30 FPS mode. FPS comes from MangoHud (presented frames); thread time from Frizti's `EDEN_NX2_GPU_PROFILE=1` zones, `top -H`, `perf` and uprobes. These are single-machine numbers, so treat them as direction, not truth.

## Where the time goes (measured on Frizti v3 + Linux pinning; the structure is the same in v4.1)
- **The GPU is not the limit:** ~45–55% busy at full clock.
- **The GPU thread split's front thread shows ~93% CPU, but most of that is a spin-wait.** About 58% of its wall time is `split drain`, waiting for the back thread at two sync points:
  - **fence releases** (~29%): semaphore acquires met by queued compute work (QMD completion releases);
  - **macro DMA reads** (~29%): Ocarina's per-object occlusion-report reads (macro 0xe2c, 24 bytes each).
- **The back thread (`GPUBack`) is ~85% busy, mostly emulator code.** The NVIDIA driver is ~13% of it. memset/memcpy ~15%, CPU texture deswizzle ~7%, buffer cache ~6%.
- **Texture uploads:** a single D32 depth buffer (Ocarina's occlusion depth, resized every frame by dynamic resolution) was ~80% of deswizzle traffic, re-uploaded from stale guest memory twice a frame. v4.1's EXP8 (bit 2) and the opt-in `EDEN_NX2_TC_SKIP_STALE` address this class of upload.

## v4.1 vs earlier builds (same machine)
- **Bedroom/Kokiri, v4.1 defaults:** averages 21–26 FPS, 1% lows 13–16, **no frame over ~95 ms**. Frizti v3 had 1% lows of 5–11 with 400–700 ms frames, and zortos293/Lichii build 117 has repeatable ~4 s CPU-side freezes.
- Run-to-run spread on v4.1 is ~1 FPS on averages. One hitch can halve a single log's 1% low, so judge lows across logs.

## Opt-in switches tried on v4.1 (Linux)
- **EXP3** (skip fence-release drain when the back has nothing to release): never engages in Ocarina, 0 skips/s (the back is always behind).
- **EXP12** (fence releases wait only for untracked writers): full drains ~1,430 → ~190/s, but the bounded waits cost nearly as much (total ~323 → ~300 ms/s). All rows 1.4–2 FPS lower, so leave it off.
- **`EDEN_NX2_OCCLUSION_OFF=1`:** removes ~90% of the occlusion-report reads. Visually clean in a first check (sun/lens flares, objects behind walls, Kokiri). FPS not yet measured. Subjectively choppier, but the frame-cadence mix (2 vs 3 refreshes) logged by v4.1 is the same as without it.

## Linux-specific gaps (open)
- **Host frame pacer off on Linux:** `DisplayRefreshQuery::Query` is Windows-only, so frames are unpaced (~63% shown for 2 refreshes, ~31% for 3 at 60 Hz). A Linux refresh query (XRandR / Wayland / present timing) is the likely fix for the uneven cadence.
- `perf` on Lichii needs `--proc-map-timeout=60000`: the process has ~100k memory mappings, and without it perf stops before libc and stacks end there.
- uprobes on LTO builds: probe C++ symbols with `perf probe --no-demangle`. Raw addresses are file offsets, which differ from addresses in lld's layout.
