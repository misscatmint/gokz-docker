#!/bin/sh

# TODO: move hostname back into launch flags (and fix quoting)?
export LD_LIBRARY_PATH="/data:/data/bin"
exec /data/srcds_linux \
    -game csgo -console -usercon -strictportbind -ip 0.0.0.0 -port 27015 \
    -noautoupdate -nobreakpad -nohltv -tickrate 128 \
    -maxplayers_override "$MAXPLAYERS" $FLAGS +servercfgfile "$SERVERCFG" \
    +"$MAPCMD" "$MAP"
