# GStreamer Ubuntu runtime

This repository builds two Ubuntu-based GStreamer runtime images with WPE
WebKit support.

- `runtime-amd64` includes VA-API, Intel Quick Sync Video, and NVIDIA NVCodec.
- `runtime-rockchip` includes Rockchip Media Process Platform and the
  `rockchipmpp` GStreamer plugin.

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

## Verify the plugin inventory

Each image runs a hardware-free plugin inventory during its build. Run the
same check in a built image with the matching variant name.

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
