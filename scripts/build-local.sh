#!/usr/bin/env bash
# Build the firmware locally with Docker instead of GitHub Actions.
#
#   scripts/build-local.sh          # left half only (the keymap lives there)
#   scripts/build-local.sh right    # right half
#   scripts/build-local.sh left right
#
# The west workspace is cached in ~/.cache/lily58-zmk, so only the first run
# downloads ZMK and Zephyr. Output: firmware/lily58_<side>.uf2
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
workspace="${LILY58_ZMK_CACHE:-$HOME/.cache/lily58-zmk}"
image="zmkfirmware/zmk-build-arm:stable"
sides=("${@:-left}")

mkdir -p "$workspace" "$repo/firmware"

docker run --rm \
    -v "$workspace:/workspace" \
    -v "$repo/config:/workspace/config:ro" \
    -v "$repo/firmware:/out" \
    -w /workspace \
    "$image" bash -euo pipefail -c '
        [ -d .west ] || west init -l config
        west update --fetch-opt=--filter=tree:0
        west zephyr-export
        for side in "$@"; do
            west build -s zmk/app -d "build/$side" -b nice_nano_v2 -- \
                -DSHIELD="lily58_$side" -DZMK_CONFIG=/workspace/config
            cp "build/$side/zephyr/zmk.uf2" "/out/lily58_$side.uf2"
        done
    ' build "${sides[@]}"

ls -l "$repo/firmware"
