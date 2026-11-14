#!/usr/bin/env bash
set -euo pipefail

export XDG_RUNTIME_DIR
XDG_RUNTIME_DIR=$(mktemp -d)
trap 'rm -rf "$XDG_RUNTIME_DIR"' EXIT
export LIBGL_ALWAYS_SOFTWARE=1

timeout 30 verify-webpage-audio media
timeout 30 verify-webpage-audio webaudio

export WPE_VIDEO_FIXTURE_DIR="$XDG_RUNTIME_DIR"
for frequency in 440 660; do
    gst-launch-1.0 -q -e \
        videotestsrc pattern=ball num-buffers=10 ! video/x-raw,width=160,height=90,framerate=10/1 \
        ! x264enc tune=zerolatency speed-preset=ultrafast ! h264parse ! queue \
        ! mp4mux name=mux ! filesink location="$WPE_VIDEO_FIXTURE_DIR/webpage-video-$frequency.mp4" \
        audiotestsrc freq="$frequency" num-buffers=48 samplesperbuffer=1000 \
        ! audio/x-raw,rate=48000 ! audioconvert ! avenc_aac ! aacparse ! queue ! mux.
done
timeout 30 verify-webpage-audio video
