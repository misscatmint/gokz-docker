FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk
ENV _VERSION=0.1 \
    APIKEY= \
    AUTHKEY= \
    DLMAP="https://csgo-kz-maps.badservers.net/maps" \
    DLMAPLIST="https://csgo-kz-maps.badservers.net/configs/maplist.txt" \
    DLMAPSUBDIRS="reuploads" \
    FASTDL="http://csgo-kz-maps.badservers.net/fastdl" \
    FLAGS= \
    HOME=/root \
    HOSTNAME= \
    MAP=kz_hikari_od \
    MAPCMD=map \
    MAPPOOL="https://csgo-kz-maps.badservers.net/configs/cfg/sourcemod/gokz/gokz-localranks-mappool.cfg" \
    MAXPLAYERS=10 \
    MINIDUMPACCOUNT= \
    PASSWORD= \
    PORT=27015 \
    REPLAYURL= \
    SERVERCFG=server.cfg

RUN echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note "" | debconf-set-selections && \
    apt-get install -y netcat steamcmd && \
    ln -s /usr/games/steamcmd /usr/bin/steamcmd
RUN --mount=type=bind,source=build.sh,target=/build.sh /build.sh
COPY check.sh entrypoint.sh run.sh /

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
            CMD /check.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/run.sh"]
