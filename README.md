# GStreamer Ubuntu runtime

This repository builds two Ubuntu-based GStreamer runtime images with WPE
WebKit support.

- `runtime-amd64` includes VA-API, Intel Quick Sync Video, and NVIDIA NVCodec.
- `runtime-rockchip` includes Rockchip Media Process Platform and the
  `rockchipmpp` GStreamer plugin, and librga 1.10.6.

The Rockchip image targets arm64 RK3588-family boards with a vendor-compatible
Linux 6.1 kernel. It is not a generic arm64 image for other boards or cloud
instances.

## Build locally

An ordinary Docker build produces the amd64 image because `runtime-amd64` is
the final Dockerfile target.

```sh
docker build --platform linux/amd64 -t gstreamer-ubuntu .
```

You can name the target explicitly.

```sh
docker build \
  --platform linux/amd64 \
  --target runtime-amd64 \
  -t gstreamer-ubuntu:amd64 \
  .

docker build \
  --platform linux/arm64 \
  --target runtime-rockchip \
  -t gstreamer-ubuntu:rockchip \
  .
```

The source archives use these optional build arguments:

```text
BUILD_JOBS=2
UBUNTU_VERSION=26.04
GSTREAMER_VERSION=1.28.2
LIBWPE_VERSION=1.16.2
WPEBACKEND_FDO_VERSION=1.16.1
WPEWEBKIT_VERSION=2.50.2
ROCKCHIP_MPP_COMMIT=c08762ebfadeb4e986d2fed993bc7a54862d3ebe
GSTREAMER_ROCKCHIP_COMMIT=1bfbba0a70ec399e3364d399b3b70691f08f52fb
```

The Rockchip commits are immutable defaults. Override them only with another
full commit hash.

## librga packaging

The Rockchip runtime includes the official GCC AArch64 `librga.so` artifact
from [airockchip/librga](https://github.com/airockchip/librga/tree/2b32edcb97b601b25683e2941d888c8515da6d55),
commit `2b32edcb97b601b25683e2941d888c8515da6d55`. Its SHA256 is
`e150bda757fb5e8a649c429ec7cabaf851aa2a3be554ed494d5519e8790d943b`.
This is the exact 1.10.6 library qualified with gateway-streamer on RK3588.
The build downloads and verifies both the binary and its Apache-2.0 license.
The license and provenance are installed under
`/opt/streamer-runtime/share/licenses/librga`.

`LIBRGA_COMMIT`, `LIBRGA_SHA256`, and `LIBRGA_LICENSE_SHA256` can be overridden
together when qualifying a replacement. The binary retains its upstream
SONAME, `librga.so`. It depends on glibc, libgcc, and libstdc++.

The build checks loading and the five symbols used by the gateway compositor
without accessing a GPU. Repeat that check in the final runtime:

```sh
docker run --rm gstreamer-ubuntu:rockchip verify-librga
```

This does not enable RGA inside `gstreamer-rockchip`; that plugin's
`-Drga=disabled` setting is unchanged. The host must still provide compatible
RGA hardware and kernel drivers for gateway-streamer compositing.

## Verify the plugin inventory

Each image runs a hardware-free plugin inventory during its build. Run the
same check in a built image with the matching variant name.

The inventory covers gateway-streamer and playlister. Playlister plays MP4,
Matroska and MPEG-TS files over HTTP(S) through `uridecodebin`, so the images
include `souphttpsrc`, `qtdemux`, `matroskademux`, `tsdemux`, `glib-networking`
for TLS, and the `x265enc` software fallback.

```sh
docker run --rm gstreamer-ubuntu:amd64 verify-plugins.sh amd64
docker run --rm gstreamer-ubuntu:rockchip verify-plugins.sh rockchip
```

The Rockchip inventory checks `rockchipmpp` and `mppvideodec`. It does not
require `mpph264enc` or `mpph265enc` because those elements probe the VPU when
GStreamer registers them.

## Verify Rockchip hardware

The Rockchip hardware check requires an RK3588-family host. It checks the
architecture and the MPP device nodes, then runs finite H.264 and H.265 encode
and decode round trips.

On a vendor-compatible kernel that exposes `/dev/mpp_service`, run:

```sh
docker run --rm \
  --device /dev/mpp_service \
  --device /dev/dri/renderD128 \
  --mount type=bind,source=/dev/dma_heap,target=/dev/dma_heap \
  gstreamer-ubuntu:rockchip \
  verify-rockchip-hardware.sh
```

Some kernels expose `/dev/rkvenc` and `/dev/rkvdec` instead of
`/dev/mpp_service`. Pass both devices in that case. MPP also needs one buffer
allocator. The verification script accepts `/dev/dma_heap`, `/dev/ion`, or a
readable and writable DRM device.

The amd64 image still uses the existing GPU access methods.

```sh
docker run --rm --device /dev/dri:/dev/dri gstreamer-ubuntu:amd64 gst-inspect-1.0 va
docker run --rm --device /dev/dri:/dev/dri gstreamer-ubuntu:amd64 gst-inspect-1.0 qsv
docker run --rm --gpus all gstreamer-ubuntu:amd64 gst-inspect-1.0 nvcodec
```

## Image tags

The GitHub Actions workflow builds amd64 on `ubuntu-latest` and Rockchip on the
native `ubuntu-24.04-arm` runner. Both jobs use separate build caches.

The amd64 image keeps the existing tags, such as `latest`, `1.2.3`, branch
names, pull request tags, and `sha-` tags. The Rockchip image adds
`-rockchip` to every tag, such as `latest-rockchip`, `1.2.3-rockchip`, and
`sha-abc1234-rockchip`.

The workflow pushes images to `ghcr.io/caiges/gstreamer-ubuntu` for the default
branch and version tags.

## Verify webpage audio

Webpage sources use `wpesrc` to capture video and audio. WebKit is built with
`ENABLE_VIDEO=ON` and `ENABLE_WEB_AUDIO=ON`; the video-only `wpevideosrc2`
plugin does not establish audio capability. GStreamer core, base, and MPEG-TS
libraries are built before WebKit so its media support links to the same
runtime libraries used by the capture plugins.

The runtime includes MP4, Matroska, WAV, MPEG-TS, and HTTP input support for
embedded media and playlist clips. Media Source Extensions and WebRTC remain
disabled.

Both native image builds run the browser audio smoke tests using software
rendering, so CI fails if the browser cannot produce audio. Repeat them in the
actual runtime image:

```sh
docker run --rm gstreamer-ubuntu:amd64 verify-webpage-audio.sh
```

Each test renders two simultaneous pages and requires actual video buffers and
the expected distinct 440/660 Hz tone from each `wpesrc`, then tears them down
and repeats the cycle to verify recreation. The `media` test plays an HTML audio
element; `webaudio` uses an `AudioContext` oscillator. The `video` test generates short moving MP4
clips and requires changing captured frames plus continuing tones over multiple
loops. A runtime with media compiled out fails even if `gst-inspect-1.0 wpesrc`
succeeds. These tests require a working EGL/Mesa
rendering environment; they do not need a sound device or network access.

A consuming Playlister image can select a locally built runtime with
`--build-arg GSTREAMER_RUNTIME_IMAGE=gstreamer-ubuntu:webpage-audio`. Publish and
qualify a runtime release with these capabilities before changing production
consumers away from their current runtime pin.

The WebKit source/build directory uses a locked BuildKit cache mount keyed by
version and architecture. Failed compiler steps retain completed objects for
the next attempt. `WEBKIT_BUILD_JOBS` overrides parallelism for only WebKit
(defaulting to `BUILD_JOBS`), so tuning it preserves cached dependency layers.
The WebKit 2.50.2 GL include patch makes its media code include
the GstGL declarations it uses rather than depending on unified-source order.

The legacy `wpesrc` shared-memory capture path copies exported pixels on the
WPE thread before releasing the Wayland buffer. This keeps queued frames valid
when a browser process dies; the existing termination error can then reach the
consumer's recovery handler instead of crashing while copying an unmapped frame.
The EGL path is unchanged.

Each WPE 2 legacy capture view owns an ephemeral network session created and
released on the WPE thread. Cookies, cache and local storage are isolated per
view and disappear when that renderer is destroyed; they are not shared across
playlist items or persisted across restarts. This also avoids the global default
session's wrong-thread destruction during normal process exit.

The legacy `wpevideosrc` child exposes `enable-autoplay` (default `false`).
Set it before PAUSED to opt into audible HTML media and Web Audio autoplay;
the choice is applied when constructing the browser view. Existing overlay
consumers retain WebKit's default muted-only autoplay policy. The runtime audio
smoke tests explicitly opt in on both captured pages.

Each WPE 2 legacy capture view also owns its WebKit context. Audio messages are
context-wide, so sharing a context sent a second page's audio to the first
source. Separate contexts preserve per-source routing when multiple webpages
are active or preloaded.

A pinned WebKit WebAudio patch releases the render-dispatch callback lock before
pushing samples or waiting for rendering to finish. Holding it during audio
backpressure blocked `AudioContext.resume()` on the browser main thread, which
also prevented the capture sink's acknowledgement from being delivered.

HTML media uses ordinary flushing seeks when looping. This avoids the pinned
WebKit segment-seek stalls in short audio and video loops. Loop boundaries may
briefly buffer; seamless or gapless looping is not promised. The audio smoke
uses one-second looped WAV files and requires the second view to keep producing
audio and video after the first view is removed.
