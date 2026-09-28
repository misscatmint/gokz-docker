#!/bin/sh

flock -n /data/.install.lock -c '' || exit 0
flock -n /data/.update.lock -c '' || exit 0
bytes=$(printf '\377\377\377\377TSource Engine Query\000' | \
    nc -u -w 4 "$(hostname -I | awk '{print $1}')" "$PORT" | wc -c)
[ "$bytes" -gt 0 ]
