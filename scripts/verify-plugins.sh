#!/usr/bin/env bash

set -euo pipefail

variant=${1:-}

common_plugins=(
  wpevideosrc2
  capsfilter
  queue
  queue2
  fakesink
  compositor
  audioconvert
  videoconvert
  videorate
  videoscale
  rtspsrc
  rtpbin
  rtpjitterbuffer
  udpsrc
  rtph264depay
  rtph265depay
  rtpmp4gdepay
  rtpmp4adepay
  rtppcmadepay
  rtppcmudepay
  rtpopusdepay
  aacparse
  opusparse
  alawdec
  mulawdec
  h264parse
  h265parse
  h264timestamper
  h265timestamper
  x264enc
  avdec_h264
  avdec_h265
  avenc_aac
  mpegtsmux
  srtsink
  flvmux
  rtmp2sink
)

case "${variant}" in
  amd64)
    variant_plugins=(va qsv nvcodec)
    ;;
  rockchip)
    variant_plugins=(rockchipmpp mppvideodec)
    ;;
  *)
    printf 'Usage: %s {amd64|rockchip}\n' "${0##*/}" >&2
    exit 64
    ;;
esac

export GST_REGISTRY="/tmp/gst-registry-verify-$$.bin"
trap 'rm -f "${GST_REGISTRY}"' EXIT

for plugin in "${common_plugins[@]}" "${variant_plugins[@]}"; do
  printf 'Checking %s\n' "${plugin}"
  gst-inspect-1.0 "${plugin}" >/dev/null
done
