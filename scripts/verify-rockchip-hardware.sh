#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

require_read_write_path() {
  local label=$1
  shift
  local path

  for path in "$@"; do
    if [[ -e "${path}" && -r "${path}" && -w "${path}" ]]; then
      return
    fi
  done

  fail "Missing readable and writable ${label}. Checked: $*"
}

case "$(uname -m)" in
  aarch64|arm64)
    ;;
  *)
    fail "Rockchip hardware verification requires arm64. Found $(uname -m)."
    ;;
esac

require_read_write_path \
  "Rockchip encoder device" \
  /dev/mpp_service \
  /dev/mpp-service \
  /dev/rkvenc

require_read_write_path \
  "Rockchip decoder device" \
  /dev/mpp_service \
  /dev/mpp-service \
  /dev/rkvdec

if [[ ! -r /dev/dma_heap ]]; then
  require_read_write_path \
    "MPP allocator device" \
    /dev/ion \
    /dev/dri/renderD128 \
    /dev/dri/card0
fi

verify-plugins.sh rockchip

gst-inspect-1.0 mpph264enc >/dev/null
gst-inspect-1.0 mpph265enc >/dev/null

run_round_trip() {
  local encoder=$1
  local parser=$2

  printf 'Running %s round trip\n' "${encoder}"
  timeout 30s gst-launch-1.0 -q -e \
    videotestsrc num-buffers=30 \
    ! video/x-raw,format=NV12,width=320,height=240,framerate=30/1 \
    ! "${encoder}" \
    ! "${parser}" \
    ! mppvideodec \
    ! fakesink sync=false
}

run_round_trip mpph264enc h264parse
run_round_trip mpph265enc h265parse
