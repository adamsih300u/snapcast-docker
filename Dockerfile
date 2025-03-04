# Build stage
FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libboost-dev \
    libexpat1-dev \
    libflac-dev \
    libvorbis-dev \
    libopus-dev \
    libasound2-dev \
    libavahi-client-dev \
    libsoxr-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build Snapcast
WORKDIR /build
RUN git clone https://github.com/badaix/snapcast.git && \
    cd snapcast && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_WITH_PULSE=OFF .. && \
    make -j"$(nproc)"

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libboost-system1.74.0 \
    libexpat1 \
    libflac12 \
    libvorbis0a \
    libopus0 \
    libasound2 \
    libavahi-client3 \
    libsoxr0 \
    mpv \
    libssl3 \
    dbus \
    # Dependencies for shairport-sync
    libpopt0 \
    libconfig9 \
    libdaemon0 \
    alsa-utils \
    # Dependencies for building shairport-sync
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    libpopt-dev \
    libconfig-dev \
    libdaemon-dev \
    libasound2-dev \
    libssl-dev \
    libsoxr-dev \
    libavahi-client-dev \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    # Create directories
    && mkdir -p /tmp/snapcast \
    && mkdir -p /etc/snapserver \
    && mkdir -p /var/lib/snapserver

# Clone and build shairport-sync
WORKDIR /tmp
RUN git clone https://github.com/mikebrady/shairport-sync.git && \
    cd shairport-sync && \
    autoreconf -i -f && \
    ./configure --with-alsa --with-avahi --with-ssl=openssl --with-soxr --with-metadata && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/shairport-sync

# Download and install librespot
RUN mkdir -p /opt/librespot/bin && \
    cd /opt/librespot/bin && \
    curl -L -o librespot.tar.gz https://github.com/librespot-org/librespot/releases/download/v0.4.2/librespot-v0.4.2-unknown-linux-gnu.tar.gz && \
    tar -xzf librespot.tar.gz && \
    rm librespot.tar.gz && \
    chmod +x librespot

# Copy binaries from builder
COPY --from=builder /build/snapcast/build/bin/snapserver /usr/local/bin/

# Create non-root user
RUN useradd -r -s /bin/false -d /home/snapserver snapserver && \
    mkdir -p /home/snapserver && \
    chown -R snapserver:snapserver /etc/snapserver /var/lib/snapserver /tmp/snapcast /home/snapserver

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