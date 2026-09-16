FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk

# TODO: rename one-time env vars to INITIAL_{ENVVAR}?
# TODO: or make them all mounts/secrets?
# TODO: multiappid/workshopfix as a build arg?
#
# initial vars:
# - AUTHKEY
# - HOSTNAME (change back to launch flag and fix quoting issues?)
# - MINIDUMPACCOUNT
# - REPLAYURL
ENV AUTHKEY= FLAGS= HOME=/root HOSTNAME= MAP=2860249917 \
    MAPCMD=host_workshop_map MINIDUMPACCOUNT= MAXPLAYERS=101 REPLAYURL= \
    SERVERCFG=server.cfg

RUN echo steam steam/question select "I AGREE" | debconf-set-selections && \
    echo steam steam/license note "" | debconf-set-selections && \
    apt-get install -y steamcmd && \
    ln -s /usr/games/steamcmd /usr/bin/steamcmd

# TODO: HEALTHCHECK directive and script to query server info

COPY entrypoint.sh run.sh /
RUN chmod +x /entrypoint.sh /run.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/run.sh"]
