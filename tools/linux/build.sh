#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# build.sh — build this tree (Fritchii v4.1, Linux port) natively with Clang + ThinLTO.
#
#   tools/linux/build.sh deps     # print the apt packages to install (run that yourself)
#   tools/linux/build.sh build    # configure + compile into $BUILD_DIR
#
# Environment (all optional):
#   BUILD_DIR  build folder, relative to the repo or absolute   (default: build)
#   MARCH      -march value                                      (default: native; tested: znver1)
#   LTO        ON or OFF (ThinLTO needs llvm-ar/llvm-ranlib)     (default: ON)
#   JOBS       parallel jobs                                     (default: nproc - 2)
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=${BUILD_DIR:-build}
[[ "$BUILD_DIR" == /* ]] || BUILD_DIR="$REPO/$BUILD_DIR"
MARCH=${MARCH:-native}
LTO=${LTO:-ON}
JOBS=${JOBS:-$(( $(nproc) > 3 ? $(nproc) - 2 : 1 ))}

case "${1:-}" in
deps)
  # From the fork's Linux CI job, plus clang/lld/llvm and the distro Qt 6 dev packages.
  cat <<'EOF'
sudo apt-get install -y --no-install-recommends \
  build-essential clang lld llvm cmake ninja-build git pkg-config autoconf libtool nasm \
  glslang-tools spirv-tools spirv-headers \
  qt6-base-dev qt6-base-private-dev qt6-tools-dev qt6-charts-dev qt6-svg-dev \
  libglu1-mesa-dev mesa-common-dev libxkbcommon-x11-0 \
  libpulse-dev libasound2-dev libudev-dev libusb-1.0-0-dev \
  libavfilter-dev libavcodec-dev libswscale-dev libva-dev libvdpau-dev \
  libboost-dev libboost-fiber-dev libboost-context-dev libopus-dev zlib1g-dev ccache
EOF
  ;;
build)
  LTO_ARGS=(-DENABLE_LTO="$LTO")
  if [[ "$LTO" == ON ]]; then
    command -v llvm-ar >/dev/null || { echo "llvm-ar missing: install llvm, or LTO=OFF"; exit 1; }
    # Clang LTO objects need LLVM's archiver; GNU ar can't index the bitcode.
    LTO_ARGS+=(-DCMAKE_AR="$(command -v llvm-ar)" -DCMAKE_RANLIB="$(command -v llvm-ranlib)"
               -DCMAKE_C_COMPILER_AR="$(command -v llvm-ar)" -DCMAKE_CXX_COMPILER_AR="$(command -v llvm-ar)"
               -DCMAKE_C_COMPILER_RANLIB="$(command -v llvm-ranlib)"
               -DCMAKE_CXX_COMPILER_RANLIB="$(command -v llvm-ranlib)")
  fi
  cmake -S "$REPO" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld" \
    -DCMAKE_C_FLAGS="-march=$MARCH" -DCMAKE_CXX_FLAGS="-march=$MARCH" \
    "${LTO_ARGS[@]}" \
    -DENABLE_WERROR=OFF -DENABLE_QT=ON -DYUZU_USE_BUNDLED_QT=OFF -DYUZU_USE_BUNDLED_SDL3=ON \
    -DVulkanHeaders_FORCE_BUNDLED=ON -DVulkanUtilityLibraries_FORCE_BUNDLED=ON \
    -DYUZU_TESTS=OFF -DBUILD_TESTING=OFF -DYUZU_ROOM=OFF -DYUZU_ROOM_STANDALONE=OFF \
    -DENABLE_UPDATE_CHECKER=OFF -DUSE_DISCORD_PRESENCE=OFF -DUSE_CCACHE=ON
  cmake --build "$BUILD_DIR" --parallel "$JOBS"
  # The release's default switches (read from the executable's folder at startup).
  cp -f "$REPO/dist/nx2_switches.txt" "$BUILD_DIR/bin/"
  echo "Built: $BUILD_DIR/bin/lichii"
  ;;
*)
  sed -n '3,13p' "$0"; exit 1 ;;
esac
