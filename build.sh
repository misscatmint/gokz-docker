#!/bin/bash

set -Eeuo pipefail

mkdir -p /build/csgo
cd /build/csgo

fetch() {
    curl -fsSL --retry 3 --create-dirs -o "$1" "$2" ||
        { echo "fetch failed: $2" >&2; return 1; }
}

# unpack [-o] [-s PREFIX] URL [member...]
#   -o  overwrite existing files (without it, zip and tar both fail on conflicts)
#   -s  the archive keeps everything under PREFIX/. Members are given relative
#       to it, and end up in the cwd without the prefix.
unpack() {
    local overwrite=() prefix=
    while [[ $1 == -* ]]; do
        case $1 in
            -o) overwrite=(-o); shift ;;
            -s) prefix=$2/; shift 2 ;;
            *)  echo "unpack: unknown option $1" >&2; return 1 ;;
        esac
    done
    local url=$1; shift
    local archive=${url##*/} members=() m
    for m in "$@"; do members+=("$prefix$m"); done

    fetch "$archive" "$url"
    case $archive in
        *.zip)    unzip -q "${overwrite[@]}" "$archive" "${members[@]}" </dev/null ;;
        *.tar.gz) tar xkf "$archive" "${members[@]}" ;;
        *)        echo "unpack: unsupported archive $archive" >&2; return 1 ;;
    esac
    rm "$archive"
    if [[ -n $prefix ]]; then
        cp -a "$prefix." . && rm -r "${prefix%%/*}"
    fi
}

# Downloads. Order matters where an archive overrides another (-o).

unpack https://github.com/zer0k-z/csgo-multi-appid/releases/download/v1.0.2/csgo-multi-appid-linux.zip
unpack https://github.com/alliedmodders/metamod-source/releases/download/1.12.0.1226/mmsource-1.12.0-git1226-linux.tar.gz
unpack https://github.com/misscatmint/mm-autorestart/releases/download/3.0.1/autorestart-linux-mm-1.12.zip
unpack https://github.com/alliedmodders/sourcemod/releases/download/1.12.0.7253/sourcemod-1.12.0-git7253-linux.tar.gz \
    --exclude=addons/sourcemod/scripting
unpack -s linux https://builds.limetech.io/files/accelerator-2.6.0-git166-a4dbe6f-linux.zip \
    'addons/sourcemod/extensions/*' 'addons/sourcemod/gamedata/*'
unpack https://github.com/nuxencs/NoLobbyReservation/releases/download/v0.0.1/NoLobbyReservation.zip \
    'addons/sourcemod/gamedata/*' 'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/fixcrash_mapchange.smx \
      https://github.com/misscatmint/csgo-fix-mapchange-crash-sm/releases/download/1.0.1/fixcrash_mapchange.smx
fetch addons/sourcemod/plugins/itemcrashfix.smx \
      https://github.com/misscatmint/itemcrashfix/releases/download/0.1/itemcrashfix.smx
fetch addons/sourcemod/plugins/CommandAliases.smx \
      https://bitbucket.org/Sikarii/sm-commandaliases/downloads/CommandAliases-latest.smx
unpack https://github.com/BadServersNet/sm-steamworks/releases/download/v1.2.168/SteamWorks-1.2.168-sm1.12-linux.tar.gz \
    addons/sourcemod/extensions
fetch addons/sourcemod/plugins/dlmap.smx \
      https://github.com/misscatmint/sm-dlmap/releases/download/0.5/dlmap.smx
unpack https://github.com/FemboyKZ/sm-server-whitelist-advanced/releases/download/1.6.2/serverwhitelistadvanced-1.6.2.zip \
    'addons/sourcemod/plugins/*'
unpack https://github.com/FemboyKZ/MovementAPI/releases/download/2.5.0/movementapi-2.5.0.zip \
    'addons/sourcemod/gamedata/*' 'addons/sourcemod/plugins/*'
unpack https://github.com/KZGlobalTeam/gokz/releases/download/3.7.0/GOKZ-v3.7.0.zip \
    'addons/sourcemod/gamedata/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'cfg/*' 'maps/*' 'materials/*' \
    'models/*' 'sound/*'
unpack -o https://github.com/misscatmint/gokz/releases/download/3.7.0-syncable-replays/GOKZ-v3.7.0-syncable-replays.zip \
    addons/sourcemod/plugins/gokz-localdb.smx \
    addons/sourcemod/plugins/gokz-localranks.smx \
    addons/sourcemod/plugins/gokz-replays.smx \
    addons/sourcemod/translations/gokz-localranks.phrases.txt \
    addons/sourcemod/translations/gokz-replays.phrases.txt
unpack https://github.com/misscatmint/csgo-sm-globalapi/releases/download/v2.1.0/GlobalAPI-v2.1.0.zip \
    'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/KZServerAdvisor.smx \
      https://github.com/KZGlobalTeam/csgo-kz-server-advisor/releases/download/1.2.0/KZServerAdvisor-v1.2.0.smx
fetch addons/sourcemod/plugins/scoreboardtimer.smx \
      https://github.com/DevRuto/GOKZ-Scoreboard-Timer/releases/download/0.05/scoreboardtimer.smx
unpack -s bsp-peek-linux-sniper--mm-1.12--sm-1.12 https://github.com/jvnipers/bsp-peek/releases/download/1.6.1/bsp-peek-linux-sniper--mm-1.12--sm-1.12.zip \
    'addons/sourcemod/extensions/*' 'addons/sourcemod/gamedata/*'
unpack https://github.com/FemboyKZ/movementhud/releases/download/v3.0.9/movementhud-v3.0.9.zip \
    'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/showpos.smx \
      https://github.com/zer0k-z/showpos/releases/download/v0.0.2/showpos.smx
unpack https://github.com/BadServersNet/sm-distbug/releases/download/v2.0.2/distbugfix-v2.0.2.tar.gz \
    ./addons/sourcemod/plugins
unpack https://github.com/BadServersNet/sm-zone-stopwatch/releases/download/v1.0.3/zone-stopwatch-v1.0.3.tar.gz \
    ./addons/sourcemod/plugins
unpack https://github.com/zer0k-z/more-stats/releases/download/v3.1.2/more-stats.zip \
    'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/showtriggers.smx \
      'https://www.sourcemod.net/vbcompiler.php?file_id=158717'
unpack https://github.com/GAMMACASE/NightVision/releases/download/1.0.1/nightvision_1.0.1.zip \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'materials/*'
fetch addons/sourcemod/plugins/its-too-dark.smx \
      https://github.com/misscatmint/its-too-dark/releases/download/1.0/its-too-dark.smx
unpack https://github.com/FemboyKZ/sm-missedby/releases/download/1.0.3/fkz-missedby.zip \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*'
unpack https://github.com/BadServersNet/sm-vanilla-tier/releases/download/v1.0.4/vanilla-tier-v1.0.4.tar.gz \
    ./addons/sourcemod/plugins
unpack https://github.com/misscatmint/gokz-ljroom-tp/releases/download/2.3.2/gokz-ljroom-tp-2.3.2.zip \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*'
unpack https://github.com/komashchenko/PTaH/releases/download/v1.1.4/linux.zip \
    'addons/sourcemod/extensions/*' 'addons/sourcemod/gamedata/*'
unpack https://github.com/kgns/weapons/releases/download/v1.7.8/weapons-v1.7.8.zip \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'cfg/*'
unpack https://github.com/kgns/gloves/releases/download/v1.0.5/gloves-v1.0.5.zip \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'cfg/*'

# Adjustments to what was downloaded.

rm addons/sourcemod/extensions/updater.ext.so
rm addons/sourcemod/extensions/x64/updater.ext.so
mv addons/sourcemod/plugins/basevotes.smx addons/sourcemod/plugins/disabled/
mv addons/sourcemod/plugins/funcommands.smx addons/sourcemod/plugins/disabled/
mv addons/sourcemod/plugins/funvotes.smx addons/sourcemod/plugins/disabled/
mv addons/sourcemod/plugins/playercommands.smx addons/sourcemod/plugins/disabled/
sed -i -E 's/("FollowCSGOServerGuidelines"[[:space:]]+)"[^"]+"/\1"no"/' \
    addons/sourcemod/configs/core.cfg
sed -i '$i\\t"MinidumpAccount"\t""' addons/sourcemod/configs/core.cfg
sed -i -E 's/^sm_weapons_chat_prefix "\[oyunhost\.net\]"$/sm_weapons_chat_prefix ""/' \
    cfg/sourcemod/weapons.cfg
sed -i -E 's/^sm_gloves_chat_prefix "\[oyunhost\.net\]"$/sm_gloves_chat_prefix ""/' \
    cfg/sourcemod/gloves.cfg

# Our own config files, laid over everything else (overlay/ mirrors /build).
cp -a /overlay/. /build/

# Changes whenever anything above does; entrypoint.sh compares against it to
# decide whether to update an existing /data volume.
find /build -type f ! -name .version -print0 | LC_ALL=C sort -z |
    xargs -0 sha256sum | sha256sum | cut -d' ' -f1 > /build/.version
