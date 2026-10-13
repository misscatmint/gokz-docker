#!/bin/bash

export LC_ALL=C
# Healthy while entrypoint.sh installs or updates, so tools that restart
# unhealthy containers don't kill the 30 GB download.
flock -n /data/.install.lock -c '' || exit 0
flock -n /data/.update.lock -c '' || exit 0
exec 3<>"/dev/udp/$(hostname -I | awk '{print $1}')/$PORT"
printf '\377\377\377\377TSource Engine Query\000' >&3
read -r -t 4 -N 1 -u 3 _ 2>/dev/null || exit 1
