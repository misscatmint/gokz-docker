#!/bin/bash
# build.sh OUT
# Assembles the add-on tree (csgo/, server.cfg, .version) in OUT, which must not
# exist yet. The Docker build runs it as /build.sh /build.

set -Eeuo pipefail

# Swappable with build args or environment variables (see README); empty means default.
: "${GOKZ:=https://github.com/misscatmint/gokz/releases/download/3.6.4-srs1/GOKZ-v3.6.4-srs1.zip}"
: "${GOKZ_SHA256:=432268d04751d42be4797970663c28c10c3edbb1f37bcbedae6bcf7e733fa838}"
: "${STEAMWORKS:=https://github.com/KyleSanderson/SteamWorks/releases/download/1.2.3c/package-lin.tgz}"
: "${STEAMWORKS_SHA256:=6679e6dfd19d4c78a71d224ff3f7d72d9becbc256082ed4bce85cbaa1e012713}"
: "${GLOBALAPI:=https://bitbucket.org/kztimerglobalteam/globalapi-smplugin/downloads/GlobalAPI-v2.0.4.zip}"
: "${GLOBALAPI_SHA256:=a986650e1fead3a438075aeaa1480f77f8033d048409de49d245bc54f34600d9}"

[[ $# == 1 && ! -e $1 ]] || { echo "usage: build.sh OUT (OUT must not exist)" >&2; exit 1; }
overlay=$(dirname "$(realpath "$0")")/overlay
mkdir -p "$1/csgo"
out=$(realpath "$1")
cd "$out/csgo"

# fetch DEST URL SHA256
fetch() {
    curl -fsSL --retry 3 --create-dirs -o "$1" "$2" ||
        { echo "fetch failed: $2" >&2; return 1; }
    echo "$3  $1" | sha256sum -c --quiet - ||
        { echo "checksum mismatch: $2" >&2; return 1; }
    # tools/bundle.sh turns this into the add-on zips' source list.
    echo "$2" >> "$out/sources.txt"
}

# unpack [-s PREFIX | -a] URL SHA256 [member...]
#   -s  the archive keeps everything under PREFIX/. Members are given relative
#       to it, and end up in the cwd without the prefix.
#   -a  like -s, with PREFIX detected: the single top-level folder, unless that's addons
unpack() {
    local prefix='' detect=''
    while [[ $1 == -* ]]; do
        case $1 in
            -s) prefix=$2/; shift 2 ;;
            -a) detect=1; shift ;;
            *)  echo "unpack: unknown option $1" >&2; return 1 ;;
        esac
    done
    local url=$1 sha256=$2; shift 2
    local archive top members=() m

    archive=$(mktemp)
    fetch "$archive" "$url" "$sha256"
    if [[ -n $detect ]]; then
        if [[ $(head -c2 "$archive") == PK ]]; then
            top=$(unzip -Z1 "$archive" | cut -d/ -f1 | sort -u)
        else
            top=$(tar tf "$archive" | cut -d/ -f1 | sort -u)
        fi
        [[ $top == *$'\n'* || $top == addons ]] || prefix=$top/
    fi
    for m in "$@"; do members+=("$prefix$m"); done
    if [[ $(head -c2 "$archive") == PK ]]; then
        unzip -q "$archive" "${members[@]}" </dev/null
    else
        tar xkf "$archive" "${members[@]}"
    fi
    rm "$archive"
    if [[ -n $prefix ]]; then
        cp -a "$prefix." . && rm -r "${prefix%%/*}"
    fi
}

# Downloads. Archives can't overlap: unzip and tar both fail on existing files.

unpack https://github.com/zer0k-z/csgo-multi-appid/releases/download/v1.0.2/csgo-multi-appid-linux.zip \
       a7b8f0073328d592481eb48f16e9e1479fac66200e9eda67b4e0ec9dce8ecc39
unpack https://github.com/alliedmodders/metamod-source/releases/download/1.12.0.1226/mmsource-1.12.0-git1226-linux.tar.gz \
       f3ab8688885c945516c2616c3e2792451615bd8ad752ed5e0b96334b49f49077
unpack https://github.com/misscatmint/mm-autorestart/releases/download/3.0.1/autorestart-linux-mm-1.12.zip \
       f2caf4528a07c27c83a1c780641d799deb37fef3835ba81bc3781b13775b4802
unpack https://github.com/alliedmodders/sourcemod/releases/download/1.12.0.7253/sourcemod-1.12.0-git7253-linux.tar.gz \
       6bbcab989cda0ada83600d0dcb0f46affd16529b2b02ed2dba1b5baeaf02fdb4 \
    --exclude=addons/sourcemod/scripting
unpack -s linux https://builds.limetech.io/files/accelerator-2.6.0-git166-a4dbe6f-linux.zip \
                01bd4a02b92ce129183e63a415dae45ca2555db23e2429fdfc99462364a7142e \
    'addons/sourcemod/extensions/*' 'addons/sourcemod/gamedata/*'
unpack https://github.com/nuxencs/NoLobbyReservation/releases/download/v0.0.1/NoLobbyReservation.zip \
       0190a963dbc4bbc4dd7f5ab2aed2363a13639159914ad3eb4f232ae7da164d37 \
    'addons/sourcemod/gamedata/*' 'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/fixcrash_mapchange.smx \
      https://github.com/misscatmint/csgo-fix-mapchange-crash-sm/releases/download/1.0.1/fixcrash_mapchange.smx \
      0aa73c9ce1cf077dff4643c4a5d43e1527783eb52d0c566e0954f918fbc0df97
fetch addons/sourcemod/plugins/itemcrashfix.smx \
      https://github.com/misscatmint/itemcrashfix/releases/download/0.1/itemcrashfix.smx \
      7d93dde1a4d381b04352416bd06612780666cc22ace18ef160a73ec8cc0a805c
fetch addons/sourcemod/plugins/CommandAliases.smx \
      https://bitbucket.org/Sikarii/sm-commandaliases/downloads/CommandAliases-latest.smx \
      92945d02eb423cb6cd9f7f845d38566cb19ecce29c71439fd48bbd2c17b44a4d
unpack -a "$STEAMWORKS" \
          "$STEAMWORKS_SHA256" \
    addons/sourcemod/extensions
fetch addons/sourcemod/plugins/dlmap.smx \
      https://github.com/misscatmint/sm-dlmap/releases/download/0.5/dlmap.smx \
      cb5aa46aaf678a958ff0511226469ca52988e5fe35815d101350d02c543d7ca4
unpack https://github.com/FemboyKZ/sm-server-whitelist-advanced/releases/download/1.6.2/serverwhitelistadvanced-1.6.2.zip \
       6d8217988ed4856ed60406f3e8f8237596ef7cf216abeba96b0e56081cd5fdeb \
    'addons/sourcemod/plugins/*'
unpack https://github.com/FemboyKZ/MovementAPI/releases/download/2.5.0/movementapi-2.5.0.zip \
       b7e79e0ea6eea8620e12fbc85fc83dbb295934ec45a15575cbd1abc3d687679b \
    'addons/sourcemod/gamedata/*' 'addons/sourcemod/plugins/*'
unpack "$GOKZ" \
       "$GOKZ_SHA256" \
    'addons/sourcemod/gamedata/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'cfg/*' 'maps/*' 'materials/*' \
    'models/*' 'sound/*'
unpack "$GLOBALAPI" \
       "$GLOBALAPI_SHA256" \
    'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/KZServerAdvisor.smx \
      https://github.com/KZGlobalTeam/csgo-kz-server-advisor/releases/download/1.2.0/KZServerAdvisor-v1.2.0.smx \
      05df9d66bd87d2873a2e8b78be35eca11656aee6cbb7b759dcacee7ac681254f
fetch addons/sourcemod/plugins/scoreboardtimer.smx \
      https://github.com/DevRuto/GOKZ-Scoreboard-Timer/releases/download/0.05/scoreboardtimer.smx \
      a1874c9524b318c1ef305ace5f3a446eff2d4af2ba3c430c250fe8f9326b3835
unpack -s bsp-peek-steamrt3--mm-1.12--sm-1.12 https://github.com/jvnipers/bsp-peek/releases/download/1.6.2/bsp-peek-steamrt3--mm-1.12--sm-1.12.zip \
                                              f749e57b812d6fa0462bfb1ac44138a31cdc8082d233ed6fc1350044b5316a3b \
    'addons/sourcemod/extensions/*' 'addons/sourcemod/gamedata/*'
unpack https://github.com/FemboyKZ/movementhud/releases/download/v3.0.9/movementhud-v3.0.9.zip \
       97d18161ea3056df9cd182cd49cdba419a38b08b695bca15cdb2365eac0b057a \
    'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/showpos.smx \
      https://github.com/zer0k-z/showpos/releases/download/v0.0.2/showpos.smx \
      591b33c829473a69a6599af1f25e3914c55be3bc6e153548e019d2d9cfb28185
unpack https://github.com/BadServersNet/sm-distbug/releases/download/v2.0.2/distbugfix-v2.0.2.tar.gz \
       89e16778a220c517f4b934012f64346f971c2942b8d454544dbcf6f93c2ccade \
    ./addons/sourcemod/plugins
unpack https://github.com/BadServersNet/sm-zone-stopwatch/releases/download/v1.0.3/zone-stopwatch-v1.0.3.tar.gz \
       8cde796a90b191f8a953bfe2561cfd1e34b791e55f27796aad990218e3ed58b5 \
    ./addons/sourcemod/plugins
unpack https://github.com/zer0k-z/more-stats/releases/download/v3.1.2/more-stats.zip \
       79721f8e511a73d636dda5b093599b2928022e74b81e9cf36634bc35502da060 \
    'addons/sourcemod/plugins/*'
fetch addons/sourcemod/plugins/showtriggers.smx \
      'https://www.sourcemod.net/vbcompiler.php?file_id=158717' \
      832f15ca3fe1a8ad14640c9f424b288077bb43548f36b28f52e9d68ccb62eaeb
unpack https://github.com/GAMMACASE/NightVision/releases/download/1.0.1/nightvision_1.0.1.zip \
       681ce9da07af14823ad56d2d72c8954920e1c2c9faee62015b10e9219a205d2c \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'materials/*'
fetch addons/sourcemod/plugins/its-too-dark.smx \
      https://github.com/misscatmint/its-too-dark/releases/download/1.0/its-too-dark.smx \
      41cadfa2a6090e2b102a8fd1235224d36592a3b12d06c63bfc7ed84c486e9909
unpack https://github.com/FemboyKZ/sm-missedby/releases/download/1.0.3/fkz-missedby.zip \
       bea547cd9ce435cdcba5d4dbc0adc66c5f3c531403e312cfafc328d66ff1b356 \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*'
unpack https://github.com/BadServersNet/sm-vanilla-tier/releases/download/v1.0.4/vanilla-tier-v1.0.4.tar.gz \
       9aa50e5c1f5522a8b98de83f99ed99f53bef0c22fe2712396fd70fabb30b3a60 \
    ./addons/sourcemod/plugins
unpack https://github.com/misscatmint/gokz-ljroom-tp/releases/download/2.3.2/gokz-ljroom-tp-2.3.2.zip \
       e7c6a879d85101ebe914d059c2c9c52c195e48828a549febdce6af04b7c16ca2 \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*'
unpack https://github.com/komashchenko/PTaH/releases/download/v1.1.4/linux.zip \
       fad4076778c7fc5abf80a3f12b34906f6b68c2ab1d1128b9ee92ce7ec412dbcf \
    'addons/sourcemod/extensions/*' 'addons/sourcemod/gamedata/*'
unpack https://github.com/kgns/weapons/releases/download/v1.7.8/weapons-v1.7.8.zip \
       8e84ac0e98b5babd248035d6a1f4e7414670314b15a54e02b547e0e0f214fc9d \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'cfg/*'
unpack https://github.com/kgns/gloves/releases/download/v1.0.5/gloves-v1.0.5.zip \
       673601f097ce793cfd8f6a33cd01fa36ff5075c5290ff7c6e3a168f57937481d \
    'addons/sourcemod/configs/*' 'addons/sourcemod/plugins/*' \
    'addons/sourcemod/translations/*' 'cfg/*'

# Adjustments to what was downloaded.

# SourceMod's auto-updater. Existing servers keep their core.cfg, so the
# DisableAutoUpdate below doesn't reach them; without the file it can't run.
rm addons/sourcemod/extensions/updater.ext.so
# The CS:GO server is 32-bit and Metamod and SourceMod only load the builds for
# the running game, so nothing ever loads the 64-bit or other games' binaries.
rm -r addons/metamod_x64.vdf addons/metamod/bin/linux64 addons/sourcemod/bin/x64 \
    addons/sourcemod/bin/sourcemod_mm.x64.so addons/sourcemod/extensions/x64
find addons/metamod/bin addons/sourcemod/bin addons/sourcemod/extensions \
    -name '*.2.*.so' ! -name '*.2.csgo.so' -delete
mv addons/sourcemod/plugins/basevotes.smx addons/sourcemod/plugins/disabled/
mv addons/sourcemod/plugins/funcommands.smx addons/sourcemod/plugins/disabled/
mv addons/sourcemod/plugins/funvotes.smx addons/sourcemod/plugins/disabled/
mv addons/sourcemod/plugins/playercommands.smx addons/sourcemod/plugins/disabled/
sed -i -E -e 's/("FollowCSGOServerGuidelines"[[:space:]]+)"[^"]+"/\1"no"/' \
    -e 's/("DisableAutoUpdate"[[:space:]]+)"[^"]+"/\1"yes"/' \
    addons/sourcemod/configs/core.cfg
sed -i -E 's/^sm_weapons_chat_prefix "\[oyunhost\.net\]"$/sm_weapons_chat_prefix ""/' \
    cfg/sourcemod/weapons.cfg
sed -i -E 's/^sm_gloves_chat_prefix "\[oyunhost\.net\]"$/sm_gloves_chat_prefix ""/' \
    cfg/sourcemod/gloves.cfg

# Our own config files, laid over everything else (overlay/ mirrors OUT).
cp -a "$overlay/." "$out/"

# Changes whenever anything above does; entrypoint.sh compares against it to
# decide whether to update an existing /data volume. Relative paths keep it the
# same wherever OUT is.
cd "$out"
version=$(find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
echo "$version" > .version
