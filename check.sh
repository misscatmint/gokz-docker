#!/bin/bash

flock -n /data/.install.lock -c '' || exit 0
flock -n /data/.update.lock -c '' || exit 0
printf '\xFF\xFF\xFF\xFF\x54Source Engine Query\x00' | \
    nc -u -w 4 "$(hostname -I | awk '{print $1}')" "$PORT" | \
    grep -q -m 1 csgo
