#!/bin/sh

export LD_LIBRARY_PATH="/data:/data/bin"
# shellcheck disable=SC2086 # FLAGS holds several options, so it's split on purpose
exec /data/srcds_linux \
     -game csgo -console -usercon -strictportbind -ip 0.0.0.0 -port "$PORT" \
     -noautoupdate -nobreakpad -nohltv -tickrate 128 \
     -maxplayers_override "$MAXPLAYERS" $FLAGS +servercfgfile "\"$SERVERCFG\"" \
     +"$MAPCMD" "$MAP"
