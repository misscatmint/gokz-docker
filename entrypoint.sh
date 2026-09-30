#!/bin/bash

set -Eeuo pipefail

# Downloads to a temp file first so a failed transfer never replaces a good file.
download() {
    local url=$1 dest=$2 tmp
    tmp="$(mktemp "$dest-XXXXXX")"
    if curl -fsSL -o "$tmp" "$url"; then mv "$tmp" "$dest"; else rm -f "$tmp"; fi
}

# Escapes the characters that are special in the replacement half of s#..#..#.
sed_escape() { printf '%s' "$1" | sed 's/[\\&#]/\\&/g'; }

# set_cvar FILE KEY VALUE: replaces the quoted value after KEY; skipped when
# VALUE is empty.
set_cvar() {
    [[ -z $3 ]] ||
        sed -i -E "s#(^[[:space:]]*$2[[:space:]]+)\"[^\"]*\"#\1\"$(sed_escape "$3")\"#" "$1"
}

# --out-format prints each file rsync creates or replaces (directories end in /).
rsync_opts=(-a --omit-dir-times --delay-updates
            --out-format='gokz-docker: updated %n')

# Files the admin moved into a disabled/ folder must not be copied back.
disabled_excludes() {
    find "$HOME/csgo/addons" -path '*/disabled/*' -type f \
         -printf '/csgo/addons/%P\n' | sed 's#/disabled/#/#'
}

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

if ! cmp -s "$HOME/.gokz-docker-version" /build/.version
then
    echo "gokz-docker: updating to $(cut -c1-12 /build/.version)"
    touch "$HOME/.update.lock"
    exec {updatelock}<>"$HOME/.update.lock"
    if ! flock -x -w 30 "$updatelock"; then
        echo "gokz-docker: failed to acquire update lock" >&2
        exit 1
    fi
    mkdir -p "$HOME/csgo/cfg" "$HOME/csgo/addons/sourcemod"
    rsync "${rsync_opts[@]}" --ignore-existing /build/server.cfg \
          "$HOME/csgo/cfg/$SERVERCFG"
    rsync "${rsync_opts[@]}" --ignore-existing /build/csgo/cfg "$HOME/csgo/"
    rsync "${rsync_opts[@]}" --ignore-existing \
          /build/csgo/addons/sourcemod/configs "$HOME/csgo/addons/sourcemod/"
    rsync "${rsync_opts[@]}" --exclude cfg --exclude addons/sourcemod/configs \
          --exclude-from=<(disabled_excludes) /build/csgo "$HOME"
    cp /build/.version "$HOME/.gokz-docker-version"
    exec {updatelock}>&-
else
    echo "gokz-docker: up to date ($(cut -c1-12 /build/.version))"
fi

sed -i -E 's#^appID=.*$#appID=4465480#' "$HOME/csgo/steam.inf"

if [[ -n "$AUTHKEY" ]]
then
    authkey="$(mktemp "$HOME/csgo/webapi_authkey.txt-XXXXXX")"
    echo "$AUTHKEY" > "$authkey"
    mv "$authkey" "$HOME/csgo/webapi_authkey.txt"
fi
set_cvar "$HOME/csgo/cfg/$SERVERCFG" hostname "$NAME"
set_cvar "$HOME/csgo/cfg/$SERVERCFG" sv_password "$PASSWORD"
set_cvar "$HOME/csgo/cfg/$SERVERCFG" sv_downloadurl "$FASTDL"
set_cvar "$HOME/csgo/addons/sourcemod/configs/core.cfg" '"MinidumpAccount"' \
         "$MINIDUMPACCOUNT"
set_cvar "$HOME/csgo/cfg/sourcemod/dlmap.cfg" sm_dlmap_url "$DLMAP"
set_cvar "$HOME/csgo/cfg/sourcemod/dlmap.cfg" sm_dlmap_maplist_url "$DLMAPLIST"
set_cvar "$HOME/csgo/cfg/sourcemod/dlmap.cfg" sm_dlmap_subdirs "$DLMAPSUBDIRS"
if [[ -n "$APIKEY" ]]
then
    apikey="$(mktemp "$HOME/csgo/cfg/sourcemod/globalapi-key.cfg-XXXXXX")"
    echo "$APIKEY" > "$apikey"
    mv "$apikey" "$HOME/csgo/cfg/sourcemod/globalapi-key.cfg"
fi

maplist="$(mktemp "$HOME/csgo/maplist.txt-XXXXXX")"
mapcycle="$(mktemp "$HOME/csgo/mapcycle.txt-XXXXXX")"
find "$HOME/csgo/maps/" -type f \
    \( -name 'bkz_*.bsp' -o -name 'kz_*.bsp' -o -name 'kzpro_*.bsp' -o \
       -name 'skz_*.bsp' -o -name 'vnl_*.bsp' -o -name 'xc_*.bsp' \) \
    | sed 's#.*/##; s#\.bsp$##' | LC_ALL=C sort -u > "$maplist"
cp "$maplist" "$mapcycle"
mv "$maplist" "$HOME/csgo/maplist.txt"
mv "$mapcycle" "$HOME/csgo/mapcycle.txt"

if [[ -n "$MAPPOOL" ]]
then
    mkdir -p "$HOME/csgo/cfg/sourcemod/gokz"
    download "$MAPPOOL" "$HOME/csgo/cfg/sourcemod/gokz/gokz-localranks-mappool.cfg"
fi

if [[ "$MAPCMD" == "map" && -n "$DLMAP" && ! -f "$HOME/csgo/maps/$MAP.bsp" ]]
then
    download "$DLMAP/$MAP.bsp" "$HOME/csgo/maps/$MAP.bsp"
    download "$DLMAP/$MAP.nav" "$HOME/csgo/maps/$MAP.nav"
fi

exec "$@"
