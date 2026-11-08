# Fritchii v4.1, Linux port (unofficial)

This branch builds **Fritchii v4.1**, Frizti's Ocarina of Time (Switch 2) fork of Lichii, natively for Linux. Upstream ships Windows binaries only. This is an **unofficial** port, not affiliated with or endorsed by Frizti or the Lichii project. All credit for the emulator and the Ocarina work goes to **Frizti** and the **Lichii / Eden contributors**; the port adds three small Linux fixes on top of tag `fritchii-v4.1` (upstream repo Frizti/Fritchii, branch `hotfix/v4.1`).

## What the port changes

| Commit | Linux problem | Fix |
|---|---|---|
| Build fix (`vk_pipeline_cache.cpp`) | v4.1 doesn't compile on Linux: Xlib.h (pulled in by the Vulkan headers) `#define`s `Status`, breaking `using Status = ...` in the pipeline cache merge loop | Name the enum via `decltype(...status)`; no behaviour change |
| GPU thread pinning (`common/thread.cpp`) | v4.1's pinning planner (`ThreadPinning::MakePlan`) is only fed a topology on Windows; on Linux the GPU front/back threads aren't pinned | Linux sysfs topology reader (cores, hybrid E-cores, L3 caches) and Linux branches of the pinning functions, same plan and `EDEN_NX2_PIN_THREADS` modes |
| Worker affinity (`common/thread.cpp`) | On Linux, threads inherit their creator's affinity, so the `ImageTranscode` pool started by GPUBack ran on GPUBack's own core | Worker threads reset to the process affinity at startup (Windows behaviour) |

Everything else, including the `EDEN_NX2_EXP*` defaults, is upstream v4.1 unchanged.

## Tested hardware

- AMD Ryzen 7 2700X (8C/16T, Zen+, two CCXs), NVIDIA RTX 3060 12 GB (proprietary driver), 32 GB RAM
- Kubuntu 26.04 (Plasma, Wayland session; Lichii running through XWayland, `gui_force_x11=true`)
- Ocarina of Time (Switch 2), docked, 30 FPS mode

Other distros and AMD/Intel GPUs are untested. Reports are welcome.

## Building

Dependencies: a recent Clang (tested 21), lld, llvm (for `llvm-ar`/`llvm-ranlib`), CMake, Ninja, Qt 6, and the usual Eden/Lichii build dependencies. External packages are fetched by CPM on first configure.

```bash
git clone --branch v41-linux https://github.com/BrewBoy360/Fritchii.git fritchii-linux
cd fritchii-linux
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld" \
  -DCMAKE_C_FLAGS="-march=native" -DCMAKE_CXX_FLAGS="-march=native" \
  -DENABLE_LTO=ON -DCMAKE_AR=$(command -v llvm-ar) -DCMAKE_RANLIB=$(command -v llvm-ranlib) \
  -DCMAKE_C_COMPILER_AR=$(command -v llvm-ar) -DCMAKE_CXX_COMPILER_AR=$(command -v llvm-ar) \
  -DCMAKE_C_COMPILER_RANLIB=$(command -v llvm-ranlib) -DCMAKE_CXX_COMPILER_RANLIB=$(command -v llvm-ranlib) \
  -DENABLE_WERROR=OFF -DENABLE_QT=ON -DYUZU_USE_BUNDLED_QT=OFF -DYUZU_USE_BUNDLED_SDL3=ON \
  -DVulkanHeaders_FORCE_BUNDLED=ON -DVulkanUtilityLibraries_FORCE_BUNDLED=ON \
  -DYUZU_TESTS=OFF -DBUILD_TESTING=OFF -DYUZU_ROOM=OFF -DYUZU_ROOM_STANDALONE=OFF \
  -DENABLE_UPDATE_CHECKER=OFF -DUSE_DISCORD_PRESENCE=OFF -DUSE_CCACHE=ON
cmake --build build --parallel
cp dist/nx2_switches.txt build/bin/   # the release's default switches (SPLIT=2, FENCE_BATCH=1)
./build/bin/lichii
```

`-march=native` builds for your own CPU. Our tested build used `-march=znver1` (Zen/Zen+). ThinLTO (`ENABLE_LTO=ON`) needs LLVM's archiver, which is why the `*_AR`/`*_RANLIB` flags are set.

Check pinning in the log (`Thread pinning (Linux): GPU front ..., GPU back ...`) or per thread:
`grep Cpus_allowed_list /proc/$(pgrep -x lichii)/task/*/status`.

## Known Linux limitations

- **Host frame pacer is off on Linux.** v4.1's pacer needs the display refresh rate, and `DisplayRefreshQuery::Query` is Windows-only, so frames are presented unpaced (shown for a mix of 2 and 3 refreshes at 60 Hz). A Linux refresh query is an open item.
- Under XWayland the NVIDIA driver offers only FIFO/Immediate VSync; a configured Mailbox falls back to FIFO.

## You supply your own keys, firmware and games

This repository contains no keys, firmware, system files or games, and none will be accepted. Dump them from your own console. Saves, shader caches and configs stay on your machine; nothing here touches them.

## Credits and license

Lichii / Eden, and Fritchii by Frizti, licensed GPL-3.0-or-later. The port's changes are under the same license. See the repository's LICENSE and the upstream projects for their authors.
