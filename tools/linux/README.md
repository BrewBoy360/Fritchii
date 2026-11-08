# tools/linux: build, run and measure the Linux port

Helper scripts used while porting and profiling Fritchii v4.1 on Linux. See `../../LINUX.md` for the port itself and `FINDINGS.md` for what profiling found. Nothing here touches your normal emulator install, keys, firmware or saves.

| Script | What it does |
|---|---|
| `build.sh deps` / `build.sh build` | Prints the apt packages; configures and builds with Clang + ThinLTO (`BUILD_DIR`, `MARCH`, `LTO`, `JOBS`) and copies `dist/nx2_switches.txt` next to the binary. |
| `sandbox-run.sh <name> <binary or AppImage>` | Runs a build with its own config/data/cache under `$SANDBOX_ROOT/<name>`. `MH=1` for MangoHud logging, `X11=1` for the xcb backend. Fixes a copied sandbox's absolute save paths so it can't use another sandbox's saves. |
| `mangohud.conf` | Overlay + logging config (Shift_L+F2 = 30 s CSV log, Shift_R+F12 = hide overlay). |
| `summarize_mangohud.py [logs…]` / `--all` | Avg FPS, 1% low, min, worst frame time, frames over 40 ms, per log (`MANGOHUD_LOGS`, default `./mangohud-logs`). |
| `affinity.sh [binary]` | Live CPU affinity per thread (GPU, GPUBack, CPUCore_*, pipeline workers, ImageTranscode). Use it to check the pinning plan logged at startup. |
| `perf-thread.sh <label>` | 20 s `perf` capture of one thread (`THREAD=GPU` default, or `GPUBack`), with the settings Lichii needs (`--proc-map-timeout=60000`, DWARF stacks). |

## Typical session

```bash
tools/linux/build.sh build
MH=1 tools/linux/sandbox-run.sh v41 build/bin/lichii   # first run: add your own keys/firmware
# in game: warm up a minute, then Shift_L+F2 per 30 s test row; quit
tools/linux/summarize_mangohud.py --all
```

Tips that saved us time:
- **Keep a read-only copy of your benchmark save** and copy it back before each session. The game's autosaves rotate through the slots and will overwrite it.
- **Change one thing per run, and restart** after changing `nx2_switches.txt` or `EDEN_NX2_*` variables; they're read at startup.
- **Judge 1% lows across several logs.** One hitch can halve a single 30 s log's 1% low.
- Frizti's built-in profiler: `EDEN_NX2_GPU_PROFILE=1` logs per-zone thread time every 10 s to the sandbox's `data/eden/log/eden_log.txt`.
