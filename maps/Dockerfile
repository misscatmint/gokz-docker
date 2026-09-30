FROM alpine:3.24.2

ARG SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.49/supercronic-linux-amd64
ARG SUPERCRONIC_SHA1SUM=e63c11a9726b775a6a11801e81af4f3fb926aa68
RUN apk add --no-cache aria2 curl && \
    curl -fsSL -o /usr/local/bin/supercronic "$SUPERCRONIC_URL" && \
    echo "${SUPERCRONIC_SHA1SUM}  /usr/local/bin/supercronic" | sha1sum -c - && \
    chmod +x /usr/local/bin/supercronic

COPY --chmod=755 crontab maps.sh /
CMD ["/usr/local/bin/supercronic", "/crontab"]
