# GStreamer Ubuntu Runtime

Docker image for a Ubuntu-based GStreamer runtime with WPE WebKit support.

The image builds GStreamer and selected plugins from source, along with libwpe,
wpebackend-fdo, and WPE WebKit. The final runtime image includes a smoke check
that verifies the expected GStreamer plugins are available.

## Build Locally

```sh
docker build -t gstreamer-ubuntu .
```

Optional build arguments:

```sh
docker build \
  --build-arg UBUNTU_VERSION=26.04 \
  --build-arg GSTREAMER_VERSION=1.28.2 \
  --build-arg LIBWPE_VERSION=1.16.2 \
  --build-arg WPEBACKEND_FDO_VERSION=1.16.0 \
  --build-arg WPEWEBKIT_VERSION=2.48.3 \
  -t gstreamer-ubuntu .
```

## Smoke Check

```sh
docker run --rm gstreamer-ubuntu gst-inspect-1.0 wpesrc
```

## GitHub Actions

This repository includes a Docker image workflow at
`.github/workflows/docker-image.yml`.

The workflow:

- Builds the Docker image for pull requests and pushes.
- Pushes images to GitHub Container Registry on the default branch and version
  tags like `1.2.3`.
- Publishes images under `ghcr.io/caiges/gstreamer-ubuntu`.
- Uses GitHub Actions cache for Docker build layers.

## Image Tags

The workflow generates tags from the Git reference, including:

- `latest` for the default branch.
- Branch and pull request tags.
- Semantic version tags from Git tags like `1.2.3`.
- SHA tags prefixed with `sha-`.
