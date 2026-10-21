#!/bin/bash

set -Eeuo pipefail

# Downloads to a temp file first so a failed transfer never replaces a good file.
# A transfer stuck under 1 KB/s for a minute fails, so a stalled server can't hang startup.
download() {
    local url=$1 dest=$2 tmp
    mkdir -p "$(dirname "$dest")"
    tmp="$(mktemp "$dest-XXXXXX")"
    # mktemp creates the file as 600; give it the usual 644 like other files.
    if curl -fsSL --speed-limit 1024 --speed-time 60 -o "$tmp" "$url"; then chmod 644 "$tmp"; mv "$tmp" "$dest"; else rm -f "$tmp"; fi
}

# --out-format prints each file rsync creates or replaces (directories end in /).
# --checksum compares contents, since every build gives downloaded files new mtimes.
rsync_opts=(-a --checksum --omit-dir-times --delay-updates
            --out-format='gokz-docker: updated %n')

# Files the admin moved into a disabled/ folder must not be copied back.
disabled_excludes() {
    find "$HOME/csgo/addons" -path '*/disabled/*' -type f \
         -printf '/csgo/addons/%P\n' | sed 's#/disabled/#/#'
}

# Files the image owns, relative to $HOME: what the last rsync below copies,
# minus maps, which stay even if a later version stops shipping them.
image_files() {
    (cd /build && find csgo -type f ! -path '*/cfg/*' \
         ! -path '*/addons/sourcemod/configs/*' ! -path 'csgo/maps/*') |
        LC_ALL=C sort
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
    rsync "${rsync_opts[@]}" --ignore-existing /build/csgo/cfg "$HOME/csgo/"
    rsync "${rsync_opts[@]}" --ignore-existing \
          /build/csgo/addons/sourcemod/configs "$HOME/csgo/addons/sourcemod/"
    rsync "${rsync_opts[@]}" --exclude cfg --exclude addons/sourcemod/configs \
          --exclude-from=<(disabled_excludes) /build/csgo "$HOME"
    # Remove what an earlier version installed but this one no longer ships.
    if [[ -f $HOME/.gokz-docker-files ]]; then
        LC_ALL=C comm -23 "$HOME/.gokz-docker-files" <(image_files) |
            while IFS= read -r f; do
                if [[ -e $HOME/$f || -L $HOME/$f ]]; then
                    rm -f -- "$HOME/$f"
                    echo "gokz-docker: removed $f"
                fi
            done
    fi
    image_files > "$HOME/.gokz-docker-files"
    cp /build/.version "$HOME/.gokz-docker-version"
    exec {updatelock}>&-
else
    echo "gokz-docker: up to date ($(cut -c1-12 /build/.version))"
fi

# On every start, so a SERVERCFG renamed after the last update still gets the defaults.
rsync "${rsync_opts[@]}" --ignore-existing /build/server.cfg "$HOME/csgo/cfg/$SERVERCFG"

sed -i -E 's#^appID=.*$#appID=4465480#' "$HOME/csgo/steam.inf"

maplist="$(mktemp "$HOME/csgo/maplist.txt-XXXXXX")"
mapcycle="$(mktemp "$HOME/csgo/mapcycle.txt-XXXXXX")"
find "$HOME/csgo/maps/" -type f \
    \( -name 'bkz_*.bsp' -o -name 'kz_*.bsp' -o -name 'kzpro_*.bsp' -o \
       -name 'skz_*.bsp' -o -name 'vnl_*.bsp' -o -name 'xc_*.bsp' \) \
    | sed 's#.*/##; s#\.bsp$##' | LC_ALL=C sort -u > "$maplist"
cp "$maplist" "$mapcycle"
chmod 644 "$maplist" "$mapcycle"
mv "$maplist" "$HOME/csgo/maplist.txt"
mv "$mapcycle" "$HOME/csgo/mapcycle.txt"

if [[ -n "$MAPPOOL" ]]
then
    mkdir -p "$HOME/csgo/cfg/sourcemod/gokz"
    download "$MAPPOOL" "$HOME/csgo/cfg/sourcemod/gokz/gokz-localranks-mappool.cfg"
fi

dlmapcfg=$HOME/csgo/cfg/sourcemod/dlmap.cfg
if [[ "$MAPCMD" == "map" && ! -f "$HOME/csgo/maps/$MAP.bsp" && -f "$dlmapcfg" ]]
then
    # Same source as !dlmap; the last sm_dlmap_url line wins, as when srcds runs the file.
    dlmap=$(sed -nE 's/^[[:space:]]*sm_dlmap_url[[:space:]]+"?([^"[:space:]]*).*/\1/p' \
                "$dlmapcfg" | tail -n 1)
    if [[ -n $dlmap ]]
    then
        download "$dlmap/$MAP.bsp" "$HOME/csgo/maps/$MAP.bsp"
        download "$dlmap/$MAP.nav" "$HOME/csgo/maps/$MAP.nav"
    fi
fi

# Accelerator uploads, then deletes, every dump it finds when srcds starts.
dumps=$HOME/csgo/addons/sourcemod/data/dumps
if [[ -d $dumps ]]; then
    mkdir -p "$HOME/crashdumps"
    find "$dumps" -maxdepth 1 -name '*.dmp*' -exec mv -t "$HOME/crashdumps" {} +
fi

exec "$@"
