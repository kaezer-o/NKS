#!/usr/bin/env bash
set -euo pipefail
VIDEO_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nekoroshell/video_wallpaper"
SOCKET="/tmp/mpvsocket"

[[ -f "$VIDEO_CACHE" ]] || exit 0
WALL="$(cat "$VIDEO_CACHE")"
[[ -f "$WALL" ]] || exit 0

if command -v lspci >/dev/null 2>&1 && lspci -k 2>/dev/null | grep -qi 'Kernel driver in use: nvidia'; then
    HWDEC="nvdec"
else
    HWDEC="auto"
fi

pkill -x mpvpaper 2>/dev/null || true
pkill -f mpvpaper-stop 2>/dev/null || true
rm -f "$SOCKET"

mpvpaper -o "--input-ipc-server=$SOCKET loop-file=inf --mute --no-osc --no-osd-bar --hwdec=$HWDEC --vo=gpu --gpu-context=wayland --no-input-default-bindings" '*' "$WALL" &
sleep 0.5
mpvpaper-stop --socket-path "$SOCKET" --period 500 --fork &
