#!/bin/bash

set -Eeuo pipefail

export HOME=/data

mkdir -p "$HOME/.steam/sdk32"
ln -sf "$HOME/.local/share/Steam/steamcmd/linux32/steamclient.so" \
    "$HOME/.steam/sdk32/"

if [[ ! -f "$HOME/csgo/bin/server.so" ]]
then
    touch "$HOME/.install.lock"
    exec {installlock}<>"$HOME/.install.lock"
    if ! flock -x -w 30 "$installlock"; then
        echo "gokz-docker: failed to acquire install lock" >&2
        exit 1
    fi
    # TODO: switch to download_depot to pin version?
    steamcmd +force_install_dir "$HOME" +login anonymous +app_update 740 +quit
    exec {installlock}>&-
fi

if [[ ! -f "$HOME/.gokz-docker-version" ||
      "$(tr -d '\n' < "$HOME/.gokz-docker-version")" != "$_VERSION" ]]
then
    echo "gokz-docker: updating gokz-docker $_VERSION"
    touch "$HOME/.update.lock"
    exec {updatelock}<>"$HOME/.update.lock"
    if ! flock -x -w 30 "$updatelock"; then
        echo "gokz-docker: failed to acquire update lock" >&2
        exit 1
    fi
    mkdir -p "$HOME/csgo/cfg" "$HOME/csgo/addons/sourcemod"
    rsync -a --delay-updates --ignore-existing /build/server.cfg \
          "$HOME/csgo/cfg/$SERVERCFG"
    rsync -a --delay-updates --ignore-existing /build/csgo/cfg "$HOME/csgo/"
    rsync -a --delay-updates --ignore-existing \
          /build/csgo/addons/sourcemod/configs "$HOME/csgo/addons/sourcemod/"
    rsync -a --delay-updates --exclude cfg --exclude addons/sourcemod/configs \
          /build/csgo "$HOME"
    echo "$_VERSION" > "$HOME/.gokz-docker-version"
    exec {updatelock}>&-
else
    echo "gokz-docker: up to date (version $_VERSION)"
fi

sed -i -E 's#^appID=.*$#appID=4465480#' "$HOME/csgo/steam.inf"

if [[ -n "$AUTHKEY" ]]
then
    authkey="$(mktemp "$HOME/csgo/webapi_authkey.txt-XXXXXX")"
    echo "$AUTHKEY" > "$authkey"
    mv "$authkey" "$HOME/csgo/webapi_authkey.txt"
fi
if [[ -n "$NAME" ]]
then
    sed -i -E 's#(hostname[[:space:]]+)"[^"]*"#\1"'"$NAME"'"#' \
        "$HOME/csgo/cfg/$SERVERCFG"
fi
if [[ -n "$PASSWORD" ]]
then
    sed -i -E 's#(sv_password[[:space:]]+)"[^"]*"#\1"'"$PASSWORD"'"#' \
        "$HOME/csgo/cfg/$SERVERCFG"
fi
if [[ -n "$FASTDL" ]]
then
    sed -i -E 's#(sv_downloadurl[[:space:]]+)"[^"]*"#\1"'"$FASTDL"'"#' \
        "$HOME/csgo/cfg/$SERVERCFG"
fi

if [[ -n "$MINIDUMPACCOUNT" ]]
then
    mkdir -p "$HOME/csgo/addons/sourcemod/configs"
    sed -i -E 's#("MinidumpAccount"[[:space:]]+)"[^"]*"#\1"'"$MINIDUMPACCOUNT"'"#' \
        "$HOME/csgo/addons/sourcemod/configs/core.cfg"
fi

if [[ -n "$DLMAP" ]]
then
    mkdir -p "$HOME/csgo/cfg/sourcemod/gokz"
    sed -i -E 's#(sm_dlmap_url[[:space:]]+)"[^"]*"#\1"'"$DLMAP"'"#' \
        "$HOME/csgo/cfg/sourcemod/dlmap.cfg"
fi
if [[ -n "$DLMAPLIST" ]]
then
    sed -i -E 's#(sm_dlmap_maplist_url[[:space:]]+)"[^"]*"#\1"'"$DLMAPLIST"'"#' \
        "$HOME/csgo/cfg/sourcemod/dlmap.cfg"
fi
if [[ -n "$DLMAPSUBDIRS" ]]
then
    sed -i -E 's#(sm_dlmap_subdirs[[:space:]]+)"[^"]*"#\1"'"$DLMAPSUBDIRS"'"#' \
        "$HOME/csgo/cfg/sourcemod/dlmap.cfg"
fi
if [[ -n "$APIKEY" ]]
then
    apikey="$(mktemp "$HOME/csgo/cfg/sourcemod/globalapi-key.cfg-XXXXXX")"
    echo "$APIKEY" > "$apikey"
    mv "$apikey" "$HOME/csgo/cfg/sourcemod/globalapi-key.cfg"
fi

maplist="$(mktemp "$HOME/csgo/maplist.txt-XXXXXX")"
mapcycle="$(mktemp "$HOME/csgo/mapcycle.txt-XXXXXX")"
find "$HOME/csgo/maps/" -type f \
    \( -name 'bkz_*.bsp*' -o -name 'kz_*.bsp*' -o -name 'kzpro_*.bsp*' -o \
       -name 'skz_*.bsp*' -o -name 'vnl_*.bsp*' -o -name 'xc_*.bsp*' \) \
    | sed 's#.*/##' | sed 's#.bsp##' | sort | uniq > "$maplist"
cat "$maplist" > "$mapcycle"
mv "$maplist" "$HOME/csgo/maplist.txt"
mv "$mapcycle" "$HOME/csgo/mapcycle.txt"

if [[ -n "$FASTDL" ]]
then
    mkdir -p "$HOME/csgo/cfg/sourcemod/gokz"
    mappool="$(mktemp "$HOME/csgo/cfg/sourcemod/gokz/gokz-localranks-mappool.cfg-XXXXXX")"
    curl -s -S --show-error -L -o "$mappool" "$MAPPOOL" && \
    mv "$mappool" "$HOME/csgo/cfg/sourcemod/gokz/gokz-localranks-mappool.cfg" || \
    true
fi

if [[ "$MAPCMD" == "map" && -n "$DLMAP" && ! -f "$HOME/csgo/maps/$MAP.bsp" ]]
then
    bsp="$(mktemp "$HOME/csgo/maps/$MAP.bsp-XXXXXX")"
    curl -s -S --show-error -L -o "$bsp" "$DLMAP/$MAP.bsp" && \
    mv "$bsp" "$HOME/csgo/maps/$MAP.bsp" || true
    nav="$(mktemp "$HOME/csgo/maps/$MAP.nav-XXXXXX")"
    curl -s -S --show-error -L -o "$nav" "$DLMAP/$MAP.nav" && \
    mv "$nav" "$HOME/csgo/maps/$MAP.nav" || true
fi

exec "$@"
