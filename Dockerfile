FROM registry.gitlab.steamos.cloud/steamrt/sniper/platform:3.0.20260928.262393@sha256:44639bcc859d574afab6bcae5f128139ef075167145eee3f757e36e8969a04e0 AS base

FROM base AS build
RUN apt-get install -y --no-install-recommends unzip
# Defaults live in build.sh.
ARG GOKZ GOKZ_SHA256 STEAMWORKS STEAMWORKS_SHA256 GLOBALAPI GLOBALAPI_SHA256
RUN --mount=type=bind,source=build.sh,target=/build.sh \
    --mount=type=bind,source=overlay,target=/overlay /build.sh /build

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
    apt-get install -y --no-install-recommends rsync steamcmd tini && \
    ln -s /usr/games/steamcmd /usr/bin/steamcmd
COPY --from=build /build /build
COPY --chmod=755 check.sh entrypoint.sh run.sh /
USER 1000:1000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5m --start-interval=10s --retries=3 \
            CMD ["/check.sh"]
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["/run.sh"]
