FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk
ENV APIKEY= \
    AUTHKEY= \
    DLMAP="https://csgo-kz-maps.badservers.net/maps" \
    DLMAPLIST="https://csgo-kz-maps.badservers.net/configs/maplist.txt" \
    DLMAPSUBDIRS="reuploads" \
    FASTDL="http://csgo-kz-maps.badservers.net/fastdl" \
    FLAGS= \
    HOME=/data \
    MAP=kz_hikari_od \
    MAPCMD=map \
    MAPPOOL="https://csgo-kz-maps.badservers.net/configs/cfg/sourcemod/gokz/gokz-localranks-mappool.cfg" \
    MAXPLAYERS=10 \
    MINIDUMPACCOUNT= \
    NAME= \
    PASSWORD= \
    PGID=1000 \
    PORT=27015 \
    PUID=1000 \
    SERVERCFG=server.cfg

RUN echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note "" | debconf-set-selections && \
    apt-get install -y netcat steamcmd tini && \
    ln -s /usr/games/steamcmd /usr/bin/steamcmd
ARG GOKZ=https://github.com/misscatmint/gokz/releases/download/3.6.4-srs1/GOKZ-v3.6.4-srs1.zip \
    STEAMWORKS=https://github.com/KyleSanderson/SteamWorks/releases/download/1.2.3c/package-lin.tgz \
    STEAMWORKS_PREFIX=package \
    GLOBALAPI=https://bitbucket.org/kztimerglobalteam/globalapi-smplugin/downloads/GlobalAPI-v2.0.4.zip
RUN --mount=type=bind,source=build.sh,target=/build.sh \
    --mount=type=bind,source=overlay,target=/overlay /build.sh
COPY --chmod=755 check.sh entrypoint.sh run.sh /

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
            CMD /check.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["/run.sh"]
