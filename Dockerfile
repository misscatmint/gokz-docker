FROM registry.gitlab.steamos.cloud/steamrt/sniper/platform:3.0.20260928.262393@sha256:44639bcc859d574afab6bcae5f128139ef075167145eee3f757e36e8969a04e0 AS base

FROM base AS build
RUN apt-get install -y --no-install-recommends unzip
ARG GOKZ=https://github.com/misscatmint/gokz/releases/download/3.6.4-srs1/GOKZ-v3.6.4-srs1.zip \
    GOKZ_SHA256=432268d04751d42be4797970663c28c10c3edbb1f37bcbedae6bcf7e733fa838 \
    STEAMWORKS=https://github.com/KyleSanderson/SteamWorks/releases/download/1.2.3c/package-lin.tgz \
    STEAMWORKS_SHA256=6679e6dfd19d4c78a71d224ff3f7d72d9becbc256082ed4bce85cbaa1e012713 \
    STEAMWORKS_PREFIX=package \
    GLOBALAPI=https://bitbucket.org/kztimerglobalteam/globalapi-smplugin/downloads/GlobalAPI-v2.0.4.zip \
    GLOBALAPI_SHA256=a986650e1fead3a438075aeaa1480f77f8033d048409de49d245bc54f34600d9
RUN --mount=type=bind,source=build.sh,target=/build.sh \
    --mount=type=bind,source=overlay,target=/overlay /build.sh

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

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
            CMD ["/check.sh"]
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["/run.sh"]
