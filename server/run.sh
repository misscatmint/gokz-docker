#!/bin/sh

# bin/ ships a libgcc_s too old for the system's libstdc++, so the system's comes first.
export LD_LIBRARY_PATH="/lib/i386-linux-gnu:/data:/data/bin"
# shellcheck disable=SC2086 # FLAGS holds several options, so it's split on purpose
exec /data/srcds_linux \
     -game csgo -console -usercon -strictportbind -ip 0.0.0.0 -port "$PORT" \
     -noautoupdate -nobreakpad -nohltv -tickrate 128 \
     -maxplayers_override "$MAXPLAYERS" $FLAGS \
     +con_logfile "logs/console-$PORT.log" +con_timestamp 1 \
     +servercfgfile "\"$SERVERCFG\"" +"$MAPCMD" "$MAP"
