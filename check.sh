#!/bin/bash

export LC_ALL=C
# Healthy until srcds starts, so tools that restart unhealthy containers
# don't kill entrypoint.sh's 30 GB install or map download.
grep -qx srcds_linux /proc/[0-9]*/comm 2>/dev/null || exit 0
exec 3<>"/dev/udp/$(hostname -I | awk '{print $1}')/$PORT"
printf '\377\377\377\377TSource Engine Query\000' >&3
read -r -t 4 -N 1 -u 3 _ 2>/dev/null || exit 1
