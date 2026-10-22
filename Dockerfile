FROM debian:trixie-20261020-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad \
     AS base
RUN sed -i -E -e 's|^# (http://snapshot\.debian\.org/.*)|URIs: \1|' \
        -e '/^URIs: http:\/\/deb\.debian\.org/d' \
        -e 's/^Components: main$/Components: main non-free/' \
        /etc/apt/sources.list.d/debian.sources && \
    echo 'Acquire::Check-Valid-Until "false";' > \
         /etc/apt/apt.conf.d/99snapshot && \
    dpkg --add-architecture i386

FROM base AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip zip && \
    rm -rf /var/lib/apt/lists/*
ARG GOKZ GOKZ_SHA256 STEAMWORKS STEAMWORKS_SHA256 GLOBALAPI GLOBALAPI_SHA256
RUN --mount=type=bind,source=server/build.sh,target=/build.sh \
    --mount=type=bind,source=server/overlay,target=/overlay /build.sh /build

FROM build AS bundler
RUN --mount=type=bind,source=tools,target=/tools \
    --mount=type=bind,source=bundle,target=/state \
    mkdir /out && cp /state/files.txt /state/removed.txt /out/ && \
    /tools/bundle.sh /build /out /out

FROM scratch AS bundle
COPY --from=bundler /out /

FROM base AS maps
ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.51/supercronic-linux-amd64
ARG SUPERCRONIC_SHA256=cc232108374e8e2b537045f2d5eaa1229f619db314c3ba6a14d38b35dc0aa123
ENV ARIA2URL=https://csgo-kz-maps.badservers.net/downloads/raw-maps.aria2.txt
# tzdata would otherwise ask for a time zone while installing.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends aria2 ca-certificates curl tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL -o /usr/local/bin/supercronic "$SUPERCRONIC_URL" && \
    echo "${SUPERCRONIC_SHA256}  /usr/local/bin/supercronic" | \
         sha256sum -c - && \
    chmod +x /usr/local/bin/supercronic
COPY --chmod=755 maps/crontab maps/maps.sh maps/publish.sh /
USER 1000:1000
CMD ["/usr/local/bin/supercronic", "/crontab"]

FROM base
ENV FLAGS= \
    HOME=/data \
    MAP=kz_hikari_od \
    MAPCMD=map \
    MAPPOOL="https://csgo-kz-maps.badservers.net/configs/cfg/sourcemod/gokz/gokz-localranks-mappool.cfg" \
    MAXPLAYERS=10 \
    PORT=27015 \
    SERVERCFG=server.cfg

RUN echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note "" | debconf-set-selections && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl logrotate \
        rsync tini libgcc-s1:i386 libstdc++6:i386 libuuid1:i386 zlib1g:i386 \
        steamcmd:i386 && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/games/steamcmd /usr/bin/steamcmd
COPY --from=build /build /build
COPY --chmod=755 server/check.sh server/entrypoint.sh server/run.sh /
COPY --chmod=644 server/logrotate.conf /
USER 1000:1000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5m \
            --start-interval=10s --retries=3 CMD ["/check.sh"]
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["/run.sh"]
