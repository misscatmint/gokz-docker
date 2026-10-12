FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.49/supercronic-linux-amd64
ARG SUPERCRONIC_SHA256=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
ENV ARIA2URL=https://csgo-kz-maps.badservers.net/downloads/raw-maps.aria2.txt \
    PGID=1000 \
    PUID=1000
RUN apk add --no-cache aria2 curl setpriv tzdata && \
    curl -fsSL -o /usr/local/bin/supercronic "$SUPERCRONIC_URL" && \
    echo "${SUPERCRONIC_SHA256}  /usr/local/bin/supercronic" | sha256sum -c - && \
    chmod +x /usr/local/bin/supercronic

COPY --chmod=755 crontab maps.sh publish.sh /
CMD ["/usr/local/bin/supercronic", "/crontab"]
