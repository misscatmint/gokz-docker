#!/bin/bash

set -Eeuo pipefail

export HOME=/data

touch "$HOME/.entrypoint.lock"
exec {fd}<>"$HOME/.entrypoint.lock"
if ! flock -x -w 30 "$fd"; then
    echo "entrypoint.sh: failed to acquire lock" >&2
    exit 1
fi

# TODO: move back into Dockerfile? (and add back steamcmd +quit?)
mkdir -p "$HOME/.steam/sdk32"
ln -sf "$HOME/.local/share/Steam/steamcmd/linux32/steamclient.so" "$HOME/.steam/sdk32/"

# TODO: switch to download_depot to pin version?
if [[ ! -d $HOME/csgo ]]; then
    steamcmd +force_install_dir "$HOME" +login anonymous +app_update 740 +quit

    # TODO: change this to sed
    cat <<EOF > "$HOME/csgo/steam.inf"
ClientVersion=1575
ServerVersion=1575
PatchVersion=1.38.8.1
ProductName=csgo
appID=4465480
SourceRevision=8413246
VersionDate=Oct 12 2023
VersionTime=09:57:39
EOF
fi

# TODO: once fastdl map server downloads work, have this combine with the
#       fastdl maplist/mapcycle files (maybe baked into the container image?)
# TODO!: download map pool file (or generate it by querying the global API?)
# TODO: consider switching to MCE (and generating map tiers from the global API)
find "$HOME/csgo/maps/" -type f \
    \( -name 'bkz_*.bsp*' -o -name 'kz_*.bsp*' -o -name 'kzpro_*.bsp*' -o \
       -name 'skz_*.bsp*' -o -name 'vnl_*.bsp*' -o -name 'xc_*.bsp*' \) \
    | sed 's!.*/!!' | sed 's!.bsp!!' | sort | uniq > "$HOME/csgo/maplist.txt"
cp "$HOME/csgo/maplist.txt" "$HOME/csgo/mapcycle.txt"

# TODO: confirm if hibernation breaks server browser queries
# TODO!: remove this and make user set it via mount/secret
# TODO!: move hostname back into launch flags (and fix quoting)?
# TODO: move debugmap reset settings into a mount/secret?
if [[ ! -f "$HOME/csgo/cfg/$SERVERCFG" ]]; then
    cat <<EOF > "$HOME/csgo/cfg/$SERVERCFG"
hostname "$HOSTNAME"
mp_autokick 0
mp_timelimit 0
sv_password ""
sv_pure 0
sv_downloadurl "http://csgo-kz-maps.badservers.net/fastdl"
sv_allowdownload 1
sm_updatemappool

sv_cheats 0
sv_autobunnyhopping 0
sm plugins load gokz-global.smx
sm plugins load gokz-anticheat.smx
gokz_settings_enforcer 1
EOF
fi

# TODO!: remove this and make user set it via mount/secret?
echo "$AUTHKEY" > "$HOME/csgo/webapi_authkey.txt"

# TODO: move into Dockerfile
if [[ ! -f "$HOME/csgo/addons/sourcemod/configs/whitelist/whitelist.txt" ]]; then
    mkdir -p "$HOME/csgo/addons/sourcemod/configs/whitelist"
    cat <<EOF > "$HOME/csgo/addons/sourcemod/configs/whitelist/whitelist.txt"
STEAM_1:0:16599865 // Chuckles
STEAM_1:1:21505111 // Sikari
STEAM_1:0:79208088 // zer0.k
STEAM_1:0:79951525 // Ruto
STEAM_1:1:120613467 // makis
STEAM_1:1:161178172 // AlphaKeks
STEAM_1:1:553718349 // Reeed
EOF
fi

# TODO: move download/extraction into Dockerfile so they go in the image
# TODO: generate initial configs regardless of installed plugin version?
# TODO!: add plugin to download map from fastdl cvar and changelevel
# TODO!: add ljroom plugin (and update to include new/missing maps)

mkdir -p "$HOME/csgo/addons/versions"

# TODO: change version check to one single check for the Dockerfile version?
is_version() {
    local addon="$1"
    local version"=$2"
    [[ ! -f "$HOME/csgo/addons/versions/$addon" ]] && return 1
    [[ "$(cat "$HOME/csgo/addons/versions/$addon")" != "$version" ]] && return 1
    return 0
}

set_version() {
    local addon="$1"
    local version="$2"
    echo "$version" > "$HOME/csgo/addons/versions/$addon"
}

download_dir="$(mktemp -d)"
cd "$download_dir"

if ! is_version metamod "1.12.0.1226"; then
    curl -s -S -L -o metamod.tar.gz https://github.com/alliedmodders/metamod-source/releases/download/1.12.0.1226/mmsource-1.12.0-git1226-linux.tar.gz
    tar xf metamod.tar.gz -C "$HOME/csgo"
    rm -rf "$HOME/csgo/addons/metamod/bin/linux64"
    set_version metamod "1.12.0.1226"
fi

if ! is_version sourcemod "1.12.0.7253"; then
    curl -s -S -L -o sourcemod.tar.gz https://github.com/alliedmodders/sourcemod/releases/download/1.12.0.7253/sourcemod-1.12.0-git7253-linux.tar.gz
    mkdir sourcemod
    tar xf sourcemod.tar.gz -C sourcemod

    rm sourcemod/addons/sourcemod/extensions/updater.ext.so
    rm -rf sourcemod/addons/sourcemod/extensions/x64

    mv sourcemod/addons/sourcemod/plugins/disabled/nominations.smx sourcemod/addons/sourcemod/plugins/
    mv sourcemod/addons/sourcemod/plugins/disabled/rockthevote.smx sourcemod/addons/sourcemod/plugins/

    sed -i -E 's/("FollowCSGOServerGuidelines"[[:space:]]+)"[^"]+"/\1"no"/' \
        sourcemod/addons/sourcemod/configs/core.cfg

    # TODO!: set on every startup
    if [[ -n "$MINIDUMPACCOUNT" ]]; then
        sed -i '$d' sourcemod/addons/sourcemod/configs/core.cfg
        cat <<EOF >> sourcemod/addons/sourcemod/configs/core.cfg

	"MinidumpAccount"	"$MINIDUMPACCOUNT"
}
EOF
    fi

    cat <<EOF > sourcemod/addons/sourcemod/configs/databases.cfg
"Databases"
{
	"driver_default"		"sqlite"

	// When specifying "host", you may use an IP address, a hostname, or a socket file path

	"default"
	{
		"driver"			"default"
		"database"			"sourcemod"
		//"user"			"root"
		//"pass"			""
		//"timeout"			"0"
		//"port"			"0"
	}
	
	"storage-local"
	{
		"driver"			"sqlite"
		"database"			"sourcemod-local"
	}

	"clientprefs"
	{
		"driver"			"sqlite"
		"database"			"clientprefs-sqlite"
	}

	"gokz"
	{
		"driver"			"sqlite"
		"database"			"gokz-sqlite"
	}

	"missedby"
	{
		"driver"			"sqlite"
		"database"			"missedby-sqlite"
	}

	"more-stats"
	{
		"driver"			"sqlite"
		"database"			"more-stats-sqlite"
	}
}
EOF

    cat <<EOF > sourcemod/addons/sourcemod/configs/admin_overrides.cfg
Overrides
{
	"sm_bhopcheck"	""
}
EOF

    mv sourcemod/addons/sourcemod/plugins/basevotes.smx sourcemod/addons/sourcemod/plugins/disabled/
    mv sourcemod/addons/sourcemod/plugins/funcommands.smx sourcemod/addons/sourcemod/plugins/disabled/
    mv sourcemod/addons/sourcemod/plugins/funvotes.smx sourcemod/addons/sourcemod/plugins/disabled/
    mv sourcemod/addons/sourcemod/plugins/playercommands.smx sourcemod/addons/sourcemod/plugins/disabled/
    mv sourcemod/addons/sourcemod/plugins/reservedslots.smx sourcemod/addons/sourcemod/plugins/disabled/

    mkdir -p "$HOME/csgo/addons/sourcemod"
    cp -an sourcemod/cfg "$HOME/csgo/"
    cp -an sourcemod/addons/sourcemod/configs "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/metamod "$HOME/csgo/addons/"
    cp -a sourcemod/addons/sourcemod/bin "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/data "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/extensions "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/gamedata "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/GPLv2.txt "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/GPLv3.txt "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/LICENSE.txt "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/logs "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/plugins "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/scripting "$HOME/csgo/addons/sourcemod/"
    cp -a sourcemod/addons/sourcemod/translations "$HOME/csgo/addons/sourcemod/"

    set_version sourcemod "1.12.0.7253"
fi

if ! is_version accelerator "2.6.0-a4dbe6f"; then
    curl -s -S -L -o accelerator.zip https://builds.limetech.io/files/accelerator-2.6.0-git166-a4dbe6f-linux.zip
    unzip -q -d accelerator -o accelerator.zip
    cp -a accelerator/linux/addons "$HOME/csgo/"
    set_version accelerator "2.6.0-a4dbe6f"
fi

if ! is_version nolobbyreservation "nuxencs-0.0.1"; then
    curl -s -S -L -o nolobbyreservation.zip https://github.com/nuxencs/NoLobbyReservation/releases/download/v0.0.1/NoLobbyReservation.zip
    unzip -q -d "$HOME/csgo" -o nolobbyreservation.zip
    set_version nolobbyreservation "nuxencs-0.0.1"
fi

if ! is_version fixmapchangecrash "1.0.1"; then
    curl -s -S --output-dir "$HOME/csgo/addons/sourcemod/plugins/" -L -O https://github.com/misscatmint/csgo-fix-mapchange-crash-sm/releases/download/1.0.1/fixcrash_mapchange.smx
    set_version fixmapchangecrash "1.0.1"
fi

if ! is_version multiappid "27e68cdd43bbfd7f0ffa60f2d4f3b9d554cb5312"; then
    curl -s -S -L -o multiappid.zip https://github.com/zer0k-z/csgo-multi-appid/releases/download/latest/csgo-multi-appid-linux.zip
    unzip -q -d "$HOME/csgo" -o multiappid.zip
    set_version multiappid "27e68cdd43bbfd7f0ffa60f2d4f3b9d554cb5312"
fi

if ! is_version restartempty "3.0"; then
    mkdir -p restartempty/addons/sourcemod/plugins
    curl -s -S --output-dir restartempty/addons/sourcemod/plugins -L -O https://github.com/misscatmint/sm-restart-empty/releases/download/3.0/sm_RestartEmpty.smx

    mkdir -p restartempty/cfg/sourcemod
    cat <<EOF > restartempty/cfg/sourcemod/sm_restart_empty.cfg
// This file was auto-generated by SourceMod (v1.12.0.7253)
// ConVars for plugin "sm_RestartEmpty.smx"


// Grace period (in sec.) waiting for new player to join until actually decide to restart the server
// -
// Default: "1.0"
sm_restart_empty_delay "120.0"

// Enable plugin (1 - On / 0 - Off)
// -
// Default: "1"
sm_restart_empty_enable "1"

// End hour for force rebooting (if last reboot happened > 24 hours ago) and somebody leaves during this hour (paired with "*_start" ConVar) (-1 to disable)
// -
// Default: "-1"
sm_restart_empty_force_hour_end "23"

// Start hour for force rebooting (if last reboot happened > 24 hours ago) and somebody leaves during this hour (paired with "*_end" ConVar) (-1 to disable)
// -
// Default: "-1"
sm_restart_empty_force_hour_start "1"

// Allow rebooting until this hour only (paired with "*_start" ConVar)
// -
// Default: "24"
sm_restart_empty_limit_hour_end "24"

// Allow rebooting to be started from this hour only (paired with "*_end" ConVar)
// -
// Default: "0"
sm_restart_empty_limit_hour_start "0"

// When server is empty, what to do? 1 - _restart, 2 - crash (use if method # 1 is not work), 3 - just change map
// -
// Default: "2"
sm_restart_empty_method "2"

// Minimum period (in hours) this plugin should wait before the next restarting is allowed (0 - disable, 24 - allow once per day)
// -
// Default: "0"
sm_restart_empty_min_period "0"

// When server restarted, change map to the random one from the file: data/restart_empty_maps.txt (1 - Yes / 0 - No)
// -
// Default: "0"
sm_restart_empty_server_start_changemap "0"

// If you have Accelerator extension, you need specify here order number of this extension in the list: sm exts list
// -
// Default: "0"
sm_restart_empty_unload_ext_num "2"

// If your server has incorrect time, you can set UTC correction hours here (they will be appended to a server time)
// -
// Default: "0.0"
sm_restart_empty_utc_delta "0.0"
EOF
    cp -an restartempty/cfg "$HOME/csgo/"
    cp -a restartempty/addons "$HOME/csgo/"

    set_version restartempty "3.0"
fi

if ! is_version movementapi "2.5.0"; then
    curl -s -S -L -o movementapi.zip https://github.com/FemboyKZ/MovementAPI/releases/download/2.5.0/movementapi-2.5.0.zip
    unzip -q -d "$HOME/csgo" -o movementapi.zip
    set_version movementapi "2.5.0"
fi

if ! is_version steamworks "git132"; then
    curl -s -S -L -o steamworks.tar.gz https://users.alliedmods.net/~kyles/builds/SteamWorks/SteamWorks-git132-linux.tar.gz
    tar xf steamworks.tar.gz -C "$HOME/csgo"
    set_version steamworks "git132"
fi

# TODO: upgrade to 3.7.0-catmint when new globalapi is released
if ! is_version gokz "3.6.4-catmint"; then
    curl -s -S -L -o gokz.zip https://github.com/misscatmint/gokz/releases/download/3.6.4-catmint/GOKZ-v3.6.4-catmint.zip
    unzip -q -d gokz -o gokz.zip

    # TODO!: set on every startup
    cat <<EOF > gokz/cfg/sourcemod/gokz/gokz-replays.cfg
// ConVars for plugin "gokz-replays.smx"


// Download link to display in console when starting a replay. Put {filename} in place of the filename.
// -
// Default: ""
gokz_replays_download_url "$REPLAYURL"
EOF

    cat <<EOF > gokz/cfg/sourcemod/gokz/options.cfg
"Options"
{
	"GOKZ - VB Indicators"
	{
		"default"	"1"
	}
	"GOKZ - Timer Button Zone Type"
	{
		"default"	"1"
	}
	"GOKZ - Tips"
	{
		"default"	"0"
	}
	"GOKZ HUD - Centre Panel"
	{
		"default"	"0"
	}
	"GOKZ HUD - Timer Text"
	{
		"default"	"3"
	}
	"GOKZ HUD - Dead Strafe"
	{
		"default"	"1"
	}
	"GOKZ HUD - Spec List Pos"
	{
		"default"	"0"
	}
	"GOKZ JS - Chat Report"
	{
		"default"	"2"
	}
	"GOKZ JS - Min Chat Broadcast"
	{
		"default"	"0"
	}
	"GOKZ Paint - Size"
	{
		"default"	"0"
	}
	"GOKZ QT - Checkpoint Volume"
	{
		"default"	"1"
	}
	"GOKZ QT - Teleport Volume"
	{
		"default"	"1"
	}
	"GOKZ QT - Timer Volume"
	{
		"default"	"3"
	}
	"GOKZ QT - Error Volume"
	{
		"default"	"1"
	}
	"GOKZ QT - Server Record Volum"
	{
		"default"	"3"
	}
	"GOKZ QT - World Record Volume"
	{
		"default"	"3"
	}
	"GOKZ QT - Jumpstats Volume"
	{
		"default"	"3"
	}
}
EOF

    cp -an gokz/cfg "$HOME/csgo/"
    cp -a gokz/addons "$HOME/csgo/"
    cp -a gokz/maps "$HOME/csgo/"
    cp -a gokz/materials "$HOME/csgo/"
    cp -a gokz/models "$HOME/csgo/"
    cp -a gokz/sound "$HOME/csgo/"
    set_version gokz "3.6.4-catmint"
fi

# TODO: move into github repo?
if ! is_version globalapi "2.0.4"; then
    curl -s -S -L -o globalapi.zip https://bitbucket.org/kztimerglobalteam/globalapi-smplugin/downloads/GlobalAPI-v2.0.4.zip
    unzip -q -d "$HOME/csgo" -o globalapi.zip
    set_version globalapi "2.0.4"
fi

if ! is_version kzserveradvisor "1.2.0"; then
    curl -s -S -L -o "$HOME/csgo/addons/sourcemod/plugins/KZServerAdvisor.smx" https://github.com/KZGlobalTeam/csgo-kz-server-advisor/releases/download/1.2.0/KZServerAdvisor-v1.2.0.smx
    set_version kzserveradvisor "1.2.0"
fi

# TODO: move into github repo?
if ! is_version commandaliases "2.0.0"; then
    curl -s -S -L -o "$HOME/csgo/addons/sourcemod/plugins/CommandAliases.smx" https://bitbucket.org/Sikarii/sm-commandaliases/downloads/CommandAliases-latest.smx
    set_version commandaliases "2.0.0"
fi

if ! is_version serverwhitelistadvanced "1.5.0"; then
    mkdir -p serverwhitelistadvanced/addons/sourcemod/plugins
    curl -s -S --output-dir serverwhitelistadvanced/addons/sourcemod/plugins -L -O https://github.com/misscatmint/sm-server-whitelist-advanced/releases/download/1.5.0/serverwhitelistadvanced.smx

    mkdir -p serverwhitelistadvanced/cfg/sourcemod
    cat <<EOF > serverwhitelistadvanced/cfg/sourcemod/serverwhitelistadvanced.cfg
// This file was auto-generated by SourceMod (v1.12.0.7253)
// ConVars for plugin "serverwhitelistadvanced.smx"


// Enable server whitelist
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
whitelist "0"

// Allows people to join if they are not whitelisted under a certain condition. 0=Nop, 1=Someone is whitelisted, 2=An admin is present (_immunity needed), 3=Someone is present.
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "3.000000"
whitelist_autovouch "0"

// Minimum time in seconds before a non-whitelisted first-time-in-map-user is kicked if no voucher (defined by _autovouch value) are present; to give time to voucher to join on mapchange. It is a minimum if Steam groups are used; if not it is a normal timeo
// -
// Default: "2.0"
// Minimum: "0.100000"
whitelist_autovouch_mintimeout "2.0"

// File name to use for the whitelist, in the sourcemod/configs/whitelist/ folder. Can't use '/' or '\'. With extension.
// -
// Default: "whitelist.txt"
whitelist_filename "whitelist.txt"

// Automatically grant admins access. Required for _autovouch = 2.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
whitelist_immunity "0"

// Message to show to kicked clients.
// -
// Default: "You are not in the server's whitelist"
whitelist_kickmessage "You are not in the server's whitelist"

// Log failed-attempts to join server. 0=No, 1=Yes (always), 2=Yes (not after first time)
// -
// Default: "1.0"
whitelist_log "1.0"

// When removing someone from whitelist, update the .txt right away (expensive operation if big whitelist) ? 0= On map end. Def. 1=Yes.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
whitelist_removeinstant "1"

// Also read SteamGroupIds from whitelist file ? 0=No. 1=Yes (SteamTools). 2=Yes (SteamWorks). Can fallback.
// -
// Default: "2"
// Minimum: "0.000000"
// Maximum: "2.000000"
whitelist_steamgroup "0"

// Maximum number of retry to do before saying someone is blacklisted. 'whitelist_steamgroup_timeout' seconds between each retry. ; Put '-1' for unlimited retry. Doing so should make people not be kicked in case Valve never respond (i.e. they have technical
// -
// Default: "-1"
// Minimum: "-1.000000"
whitelist_steamgroup_retry "-1"

// Time (in seconds) before re-requesting SteamGroups status from Valve's server (sometimes Valve doesn't answer).
// -
// Default: "0.34"
// Minimum: "0.010000"
whitelist_steamgroup_timeout "0.34"

// Use whitelist_kickmessage through tidykick ? 0=No (Default; need TidyKick). 1=Yes.
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
whitelist_tidykick "0"
EOF

    set_version serverwhitelistadvanced "1.5.0"
fi

if ! is_version scoreboardtimer "0.05"; then
    curl -s -S --output-dir "$HOME/csgo/addons/sourcemod/plugins/" -L -O https://github.com/DevRuto/GOKZ-Scoreboard-Timer/releases/download/0.05/scoreboardtimer.smx
    set_version scoreboardtimer "0.05"
fi

if ! is_version bsppeek "1.6.1"; then
    curl -s -S -L -o bsppeek.zip https://github.com/jvnipers/bsp-peek/releases/download/1.6.1/bsp-peek-linux-sniper--mm-1.12--sm-1.12.zip
    unzip -q bsppeek.zip
    cp -a bsp-peek-linux-sniper--mm-1.12--sm-1.12/addons "$HOME/csgo"
    set_version bsppeek "1.6.1"
fi

if ! is_version movementhud "3.0.9"; then
    curl -s -S -L -o movementhud.zip https://github.com/FemboyKZ/movementhud/releases/download/v3.0.9/movementhud-v3.0.9.zip
    unzip -q -d movementhud -o movementhud.zip

    # TODO!: make jb color default yellow
    # TODO!: make eb color default something
    # TODO!: make px color default something?
    mkdir -p movementhud/cfg/sourcemod
    cat <<EOF > movementhud/cfg/sourcemod/movementhud-defaults.cfg
"MovementHUD-Defaults"
{
	"keys_mode"		"2"
	"speed_mode"		"1"
	"indicators_jb_enabled"	"1"
	"indicators_cj_enabled"	"1"
	"indicators_eb_enabled"	"1"
	"indicators_px_enabled"	"1"
	"indicators_ftg"	"1"
	"indicators_crouch"	"1"
	"distpred_mode"		"1"
}
EOF

    cp -an movementhud/cfg "$HOME/csgo/"
    cp -a movementhud/addons "$HOME/csgo/"
    set_version movementhud "3.0.9"
fi

if ! is_version showpos "0.0.2"; then
    curl -s -S --output-dir "$HOME/csgo/addons/sourcemod/plugins/" -L -O https://github.com/zer0k-z/showpos/releases/download/v0.0.2/showpos.smx
    set_version showpos "0.0.2"
fi

if ! is_version distbug "2.0.2"; then
    curl -s -S -L -o distbug.tar.gz https://github.com/BadServersNet/sm-distbug/releases/download/v2.0.2/distbugfix-v2.0.2.tar.gz
    tar xf distbug.tar.gz -C "$HOME/csgo"
    set_version distbug "2.0.2"
fi

if ! is_version ztopwatch "1.0.3"; then
    curl -s -S -L -o ztopwatch.tar.gz https://github.com/BadServersNet/sm-zone-stopwatch/releases/download/v1.0.3/zone-stopwatch-v1.0.3.tar.gz
    tar xf ztopwatch.tar.gz -C "$HOME/csgo"
    set_version ztopwatch "1.0.3"
fi

if ! is_version morestats "3.1.2"; then
    curl -s -S -L -o morestats.zip https://github.com/zer0k-z/more-stats/releases/download/v3.1.2/more-stats.zip
    unzip -q -d "$HOME/csgo" -o morestats.zip
    set_version morestats "3.1.2"
fi

if ! is_version showtriggers "1.1"; then
    curl -s -S -L -o "$HOME/csgo/addons/sourcemod/plugins/showtriggers.smx" 'https://www.sourcemod.net/vbcompiler.php?file_id=158717'
    set_version showtriggers "1.1"
fi

if ! is_version nightvision "1.0.1"; then
    curl -s -S -L -o nightvision.zip https://github.com/GAMMACASE/NightVision/releases/download/1.0.1/nightvision_1.0.1.zip
    unzip -q -d "$HOME/csgo" -o nightvision.zip
    set_version nightvision "1.0.1"
fi

if ! is_version itstoodark "1.0"; then
    curl -s -S --output-dir "$HOME/csgo/addons/sourcemod/plugins" -L -O https://github.com/misscatmint/its-too-dark/releases/download/1.0/its-too-dark.smx
    set_version itstoodark "1.0"
fi

if ! is_version antifun "0.0.1"; then
    curl -s -S -L -o antifun.zip https://github.com/FemboyKZ/anti-fun/releases/download/0.0.1/anti-fun-csgo.zip
    unzip -q -d "$HOME/csgo" -o antifun.zip
    set_version antifun "0.0.1"
fi

if ! is_version missedby "1.0.3"; then
    curl -s -S -L -o missedby.zip https://github.com/FemboyKZ/sm-missedby/releases/download/1.0.3/fkz-missedby.zip
    unzip -q -d "$HOME/csgo" -o missedby.zip
    set_version missedby "1.0.3"
fi

if ! is_version vanillatier "1.0.4"; then
    curl -s -S -L -o vanillatier.tar.gz https://github.com/BadServersNet/sm-vanilla-tier/releases/download/v1.0.4/vanilla-tier-v1.0.4.tar.gz
    tar xf vanillatier.tar.gz -C "$HOME/csgo"
    set_version vanillatier "1.0.4"
fi

if ! is_version smjansson "2.3.1.3"; then
    curl -s -S -L -o smjansson.zip https://github.com/jvnipers/SMJansson/releases/download/2.3.1.3/smjansson_2.3.1.3.zip
    unzip -q smjansson.zip
    mv addons/sourcemod/extensions/smjansson.ext.so "$HOME/csgo/addons/sourcemod/extensions/"
    set_version smjansson "2.3.1.3"
fi

if ! is_version kztiermapchooser "42218acd6d85799e0f64e46878cb8079e8e9868b"; then
    curl -s -S --output-dir "$HOME/csgo/addons/sourcemod/plugins" -L -O https://github.com/FemboyKZ/KZTierMapchooser/raw/42218acd6d85799e0f64e46878cb8079e8e9868b/compiled/mapchooser_tier.smx
    # TODO!: cfg/sourcemod/mapchooser.cfg?
    # TODO!: sm_mapvote_novote 0
    # TODO!: fix map not changing immediately and all changelevel commands breaking
    set_version kztiermapchooser "42218acd6d85799e0f64e46878cb8079e8e9868b"
fi

if ! is_version ptah "1.1.4"; then
    curl -s -S -L -o ptah.zip https://github.com/komashchenko/PTaH/releases/download/v1.1.4/linux.zip
    unzip -q -d "$HOME/csgo" -o ptah.zip
    set_version ptah "1.1.4"
fi

if ! is_version weapons "1.7.8"; then
    curl -s -S -L -o weapons.zip https://github.com/kgns/weapons/releases/download/v1.7.8/weapons-v1.7.8.zip
    unzip -q -d weapons -o weapons.zip

    sed -i -E 's/^sm_weapons_chat_prefix "\[oyunhost\.net\]"$/sm_weapons_chat_prefix ""/' \
        weapons/cfg/sourcemod/weapons.cfg
    cp -an weapons/cfg "$HOME/csgo/"
    cp -a weapons/addons "$HOME/csgo/"

    set_version weapons "1.7.8"
fi

if ! is_version gloves "1.0.5"; then
    curl -s -S -L -o gloves.zip https://github.com/kgns/gloves/releases/download/v1.0.5/gloves-v1.0.5.zip
    unzip -q -d gloves -o gloves.zip

    sed -i -E 's/^sm_gloves_chat_prefix "\[oyunhost\.net\]"$/sm_gloves_chat_prefix ""/' \
        gloves/cfg/sourcemod/gloves.cfg
    cp -an gloves/cfg "$HOME/csgo/"
    cp -a gloves/addons "$HOME/csgo/"

    set_version gloves "1.0.5"
fi

cd /
rm -rf "$download_dir"

# TODO: remove this?
if [[ "$MAPCMD" == "map" && ! -f "$HOME/csgo/maps/$MAP.bsp" ]]; then
    curl -s -S --output-dir "$HOME/csgo/maps" -L -O "https://csgo-kz-maps.badservers.net/maps/$MAP.bsp"
    curl -s -S --output-dir "$HOME/csgo/maps" -L -O "https://csgo-kz-maps.badservers.net/maps/$MAP.nav"
fi

exec "$@"
