# Build stage
FROM alpine:3.19 AS builder

# Install build dependencies
# hadolint ignore=DL3018
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    boost-dev \
    expat-dev \
    flac-dev \
    libvorbis-dev \
    opus-dev \
    alsa-lib-dev \
    avahi-dev \
    soxr-dev \
    openssl-dev

# Clone and build Snapcast
WORKDIR /build
RUN git clone https://github.com/badaix/snapcast.git && \
    cd snapcast && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_WITH_PULSE=OFF .. && \
    make -j"$(nproc)"

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
# hadolint ignore=DL3018
RUN apk add --no-cache \
    boost-libs \
    expat \
    flac \
    libvorbis \
    opus \
    alsa-lib \
    avahi-libs \
    soxr \
    mpv \
    openssl \
    dbus \
    # Dependencies for shairport-sync
    popt \
    libconfig \
    libdaemon \
    alsa-utils \
    # Create directories
    && mkdir -p /tmp/snapcast \
    && mkdir -p /etc/snapserver \
    && mkdir -p /var/lib/snapserver

# Install shairport-sync from source
# hadolint ignore=DL3018
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    git \
    autoconf \
    automake \
    libtool \
    popt-dev \
    libconfig-dev \
    libdaemon-dev \
    alsa-lib-dev \
    openssl-dev \
    soxr-dev \
    avahi-dev

# Clone and build shairport-sync
WORKDIR /tmp
RUN git clone https://github.com/mikebrady/shairport-sync.git && \
    cd shairport-sync && \
    autoreconf -i -f && \
    ./configure --with-alsa --with-avahi --with-ssl=openssl --with-soxr --with-metadata && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/shairport-sync && \
    apk del .build-deps

# Install librespot from source
# hadolint ignore=DL3018
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    cargo \
    rust \
    alsa-lib-dev

# Build librespot with a specific version that's compatible with Alpine's Rust
WORKDIR /tmp
RUN mkdir -p /opt/librespot/bin && \
    cargo install librespot@0.4.2 --locked --root=/opt/librespot && \
    apk del .build-deps

# Copy binaries from builder
COPY --from=builder /build/snapcast/build/bin/snapserver /usr/local/bin/

# Create non-root user
RUN adduser -D -h /home/snapserver snapserver && \
    chown -R snapserver:snapserver /etc/snapserver /var/lib/snapserver /tmp/snapcast

# Create fifo file
RUN mkfifo /tmp/snapfifo && \
    chmod 644 /tmp/snapfifo && \
    chown snapserver:snapserver /tmp/snapfifo

# Set up configuration
VOLUME ["/etc/snapserver", "/var/lib/snapserver"]

# Switch to non-root user
USER snapserver
WORKDIR /home/snapserver

# Expose ports
# 1704: TCP control port
# 1705: TCP streaming port
# 1780: HTTP API port
EXPOSE 1704 1705 1780
# 5000: AirPlay port
EXPOSE 5000/tcp 5000/udp
# 5353: Avahi/mDNS
EXPOSE 5353/udp

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:1780/v2/server/status || exit 1

# Start Snapserver
ENTRYPOINT ["/usr/local/bin/snapserver"]
CMD ["--config=/etc/snapserver/snapserver.conf"] 