# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=26.04
ARG PREFIX=/opt/streamer-runtime
ARG GSTREAMER_VERSION=1.28.2
ARG LIBWPE_VERSION=1.16.2
ARG WPEBACKEND_FDO_VERSION=1.16.1
ARG WPEWEBKIT_VERSION=2.50.2
ARG ROCKCHIP_MPP_COMMIT=c08762ebfadeb4e986d2fed993bc7a54862d3ebe
ARG GSTREAMER_ROCKCHIP_COMMIT=1bfbba0a70ec399e3364d399b3b70691f08f52fb

FROM ubuntu:${UBUNTU_VERSION} AS source-build-common

ARG PREFIX
ARG GSTREAMER_VERSION
ARG LIBWPE_VERSION
ARG WPEBACKEND_FDO_VERSION
ARG WPEWEBKIT_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV PREFIX=${PREFIX}
ENV PATH=${PREFIX}/bin:${PATH}
ENV PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig
ENV LD_LIBRARY_PATH=${PREFIX}/lib

RUN apt-get update && apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    flex \
    gperf \
    libavif-dev \
    libavcodec-dev \
    libavfilter-dev \
    libavformat-dev \
    libavutil-dev \
    libcairo2-dev \
    libdrm-dev \
    libegl1-mesa-dev \
    libepoxy-dev \
    libfontconfig-dev \
    libfreetype-dev \
    libgbm-dev \
    libgles-dev \
    libglib2.0-dev \
    libgcrypt20-dev \
    libgudev-1.0-dev \
    libharfbuzz-dev \
    libicu-dev \
    libinput-dev \
    libjpeg-dev \
    libjxl-dev \
    liblcms2-dev \
    libopenjp2-7-dev \
    liborc-0.4-dev \
    libopus-dev \
    libpng-dev \
    libsoup-3.0-dev \
    libseccomp-dev \
    libsrt-gnutls-dev \
    libsqlite3-dev \
    libswresample-dev \
    libswscale-dev \
    libsystemd-dev \
    libudev-dev \
    libtasn1-6-dev \
    libva-dev \
    libwayland-dev \
    libwebp-dev \
    libwoff-dev \
    libx264-dev \
    libxkbcommon-dev \
    libxml2-dev \
    libxslt1-dev \
    meson \
    ninja-build \
    pkg-config \
    python3 \
    ruby-dev \
    unifdef \
    wayland-protocols \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build

RUN curl -fsSL "https://wpewebkit.org/releases/libwpe-${LIBWPE_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://wpewebkit.org/releases/wpebackend-fdo-${WPEBACKEND_FDO_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://wpewebkit.org/releases/wpewebkit-${WPEWEBKIT_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && cmake -S . -B build -GNinja \
        -DPORT=WPE \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${PREFIX} \
        -DENABLE_ACCESSIBILITY=OFF \
        -DENABLE_BUBBLEWRAP_SANDBOX=OFF \
        -DENABLE_DOCUMENTATION=OFF \
        -DENABLE_GAMEPAD=OFF \
        -DENABLE_WPE_PLATFORM=ON \
        -DENABLE_INTROSPECTION=OFF \
        -DENABLE_MEDIA_SOURCE=OFF \
        -DENABLE_MEDIA_STREAM=OFF \
        -DENABLE_MINIBROWSER=OFF \
        -DENABLE_SPEECH_SYNTHESIS=OFF \
        -DENABLE_VIDEO=OFF \
        -DENABLE_WEB_AUDIO=OFF \
        -DENABLE_WEB_CODECS=OFF \
        -DENABLE_WEBGL=ON \
        -DENABLE_WEBGPU=OFF \
        -DENABLE_WEBDRIVER=OFF \
        -DENABLE_WEB_RTC=OFF \
        -DENABLE_WEBXR=OFF \
        -DUSE_ATK=OFF \
        -DUSE_LIBBACKTRACE=OFF \
    && cmake --build build --target install --parallel "$(nproc)" \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://gstreamer.freedesktop.org/src/gstreamer/gstreamer-${GSTREAMER_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Ddoc=disabled \
        -Dexamples=disabled \
        -Dnls=disabled \
        -Dtests=disabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-${GSTREAMER_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Ddoc=disabled \
        -Dexamples=disabled \
        -Dgl=enabled \
        -Dintrospection=disabled \
        -Dnls=disabled \
        -Dtests=disabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://gstreamer.freedesktop.org/src/gst-plugins-good/gst-plugins-good-${GSTREAMER_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Dauto_features=disabled \
        -Daudioparsers=enabled \
        -Ddoc=disabled \
        -Dexamples=disabled \
        -Dflv=enabled \
        -Dlaw=enabled \
        -Dnls=disabled \
        -Drtp=enabled \
        -Drtpmanager=enabled \
        -Drtsp=enabled \
        -Dtests=disabled \
        -Dudp=enabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://gstreamer.freedesktop.org/src/gst-plugins-ugly/gst-plugins-ugly-${GSTREAMER_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Dauto_features=disabled \
        -Ddoc=disabled \
        -Dgpl=enabled \
        -Dnls=disabled \
        -Dtests=disabled \
        -Dx264=enabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://gstreamer.freedesktop.org/src/gst-libav/gst-libav-${GSTREAMER_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Ddoc=disabled \
        -Dtests=disabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

FROM source-build-common AS source-build-amd64

ARG PREFIX
ARG GSTREAMER_VERSION
ARG TARGETARCH

RUN test "${TARGETARCH}" = amd64 \
    && curl -fsSL "https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-${GSTREAMER_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Dauto_features=disabled \
        -Dcodectimestamper=enabled \
        -Ddoc=disabled \
        -Dexamples=disabled \
        -Dgl=enabled \
        -Dintrospection=disabled \
        -Dmpegtsmux=enabled \
        -Dnls=disabled \
        -Dnvcodec=enabled \
        -Dopus=enabled \
        -Dqsv=enabled \
        -Drtmp2=enabled \
        -Dsrt=enabled \
        -Dtests=disabled \
        -Dudev=enabled \
        -Dva=enabled \
        -Dvideoparsers=enabled \
        -Dwpe=enabled \
        -Dwpe_api=2.0 \
        -Dwpe2=enabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

FROM source-build-common AS source-build-rockchip

ARG PREFIX
ARG GSTREAMER_VERSION
ARG ROCKCHIP_MPP_COMMIT
ARG GSTREAMER_ROCKCHIP_COMMIT
ARG TARGETARCH

RUN test "${TARGETARCH}" = arm64 \
    && curl -fsSL "https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-${GSTREAMER_VERSION}.tar.xz" \
    | tar -xJ --strip-components=1 \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Dauto_features=disabled \
        -Dcodectimestamper=enabled \
        -Ddoc=disabled \
        -Dexamples=disabled \
        -Dgl=enabled \
        -Dintrospection=disabled \
        -Dmpegtsmux=enabled \
        -Dnls=disabled \
        -Dnvcodec=disabled \
        -Dopus=enabled \
        -Dqsv=disabled \
        -Drtmp2=enabled \
        -Dsrt=enabled \
        -Dtests=disabled \
        -Dudev=enabled \
        -Dva=enabled \
        -Dvideoparsers=enabled \
        -Dwpe=enabled \
        -Dwpe_api=2.0 \
        -Dwpe2=enabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

RUN curl -fsSL "https://github.com/rockchip-linux/mpp/archive/${ROCKCHIP_MPP_COMMIT}.tar.gz" \
    | tar -xz --strip-components=1 \
    && cmake -S . -B build -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${PREFIX} \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_TEST=OFF \
    && cmake --build build --parallel "$(nproc)" \
    && cmake --install build \
    && rm -rf /tmp/build/*

# The archive has no Git metadata, but its Meson setup installs a hook.
RUN curl -fsSL "https://github.com/yanyitech/gstreamer-rockchip/archive/${GSTREAMER_ROCKCHIP_COMMIT}.tar.gz" \
    | tar -xz --strip-components=1 \
    && mkdir -p .git/hooks \
    && meson setup build . \
        --prefix=${PREFIX} \
        --libdir=lib \
        --buildtype=release \
        -Dkmssrc=disabled \
        -Drga=disabled \
        -Drkximage=disabled \
        -Drockchipmpp=enabled \
        -Dvpxalphadec=disabled \
    && meson compile -C build \
    && meson install -C build \
    && rm -rf /tmp/build/*

FROM ubuntu:${UBUNTU_VERSION} AS runtime-common

ARG PREFIX

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=${PREFIX}/bin:${PATH}
ENV LD_LIBRARY_PATH=${PREFIX}/lib
ENV GST_PLUGIN_SYSTEM_PATH=${PREFIX}/lib/gstreamer-1.0
ENV GST_PLUGIN_SCANNER=${PREFIX}/libexec/gstreamer-1.0/gst-plugin-scanner

RUN apt-get update && apt-get install -y --no-install-recommends \
    bubblewrap \
    ca-certificates \
    fonts-dejavu-core \
    libavif16 \
    libavcodec62 \
    libavfilter11 \
    libavformat62 \
    libavutil60 \
    libcairo2 \
    libdrm2 \
    libegl1 \
    libepoxy0 \
    libfontconfig1 \
    libfreetype6 \
    libgbm1 \
    libgcrypt20 \
    libgpg-error0 \
    libgl1-mesa-dri \
    libgles2 \
    libglib2.0-0t64 \
    libglx-mesa0 \
    libgudev-1.0-0 \
    libharfbuzz-icu0 \
    libharfbuzz0b \
    libicu78 \
    libinput10 \
    libjpeg-turbo8 \
    libjxl0.11 \
    liblcms2-2 \
    libopenjp2-7 \
    liborc-0.4-0t64 \
    libopus0 \
    libpng16-16t64 \
    libsoup-3.0-0 \
    libseccomp2 \
    libsrt1.5-gnutls \
    libsqlite3-0 \
    libswresample6 \
    libswscale9 \
    libsystemd0 \
    libudev1 \
    libtasn1-6 \
    libva2 \
    libva-drm2 \
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-egl1 \
    libwayland-server0 \
    libwebp7 \
    libwebpdemux2 \
    libwoff1 \
    libx264-165 \
    libxkbcommon0 \
    libxml2-16 \
    libxslt1.1 \
    mesa-libgallium \
    mesa-vulkan-drivers \
    xdg-dbus-proxy \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 scripts/verify-plugins.sh /usr/local/bin/verify-plugins.sh
COPY --chmod=0755 scripts/verify-rockchip-hardware.sh /usr/local/bin/verify-rockchip-hardware.sh

FROM runtime-common AS runtime-rockchip

ARG PREFIX
ARG TARGETARCH

RUN test "${TARGETARCH}" = arm64

COPY --from=source-build-rockchip ${PREFIX} ${PREFIX}

RUN verify-plugins.sh rockchip \
    && rm -rf /root/.cache/gstreamer-1.0

FROM runtime-common AS runtime-amd64

ARG PREFIX
ARG TARGETARCH

RUN test "${TARGETARCH}" = amd64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        intel-media-va-driver \
        libmfx-gen1.2 \
        libvpl2 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=source-build-amd64 ${PREFIX} ${PREFIX}

RUN verify-plugins.sh amd64 \
    && rm -rf /root/.cache/gstreamer-1.0
