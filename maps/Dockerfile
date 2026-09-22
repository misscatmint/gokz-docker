FROM alpine:3.24.2
RUN apk add --no-cache aria2 curl

COPY crontab /etc/crontabs/maps
COPY maps.sh /
CMD ["crond", "-f"]
