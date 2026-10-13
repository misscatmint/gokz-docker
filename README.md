# gokz-docker

Docker images for running a CS:GO [GOKZ](https://github.com/KZGlobalTeam/gokz)
server, with quality of life plugins and modern default settings included.

## Example `compose.yaml`

```yaml
services:
  gokz:
    container_name: gokz
    restart: unless-stopped
    stdin_open: true
    tty: true
    build: ./gokz-docker
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    environment:
      MAP: kz_vnl_crimdaughter
      MAXPLAYERS: 16
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./gokz/data:/data
      - ./gokz/etc/addons/sourcemod/configs:/data/csgo/addons/sourcemod/configs
      - ./gokz/etc/cfg:/data/csgo/cfg
    ports:
      - 27015:27015/udp
      - 127.0.0.1:27015:27015/tcp  # RCON only; drop 127.0.0.1: to reach it remotely
```

```sh
mkdir -p gokz/data/csgo/cfg gokz/data/csgo/addons/sourcemod/configs \
         gokz/data/csgo/maps gokz/etc/cfg gokz/etc/addons/sourcemod/configs
sudo chown -R 1000:1000 gokz    # skip on rootless Docker, see Permissions
docker compose up -d
docker attach gokz    # server console (detach with Ctrl-P Ctrl-Q)
```

Both containers use the host's timezone through the `/etc/localtime` mount. To
give a container its own timezone instead, drop the mount and set `TZ`, e.g.
`TZ: America/Chicago`.

The first start downloads the CS:GO dedicated server (~30 GB) and can take a
while. Only the `/data` volume is required. The two config mounts are optional
and just keep your configs in a separate, easy-to-edit place.

## Configuration

These control how the server starts. Everything else, like the server name, is
set in the config files.

| Variable | Default | Description |
| --- | --- | --- |
| `MAP` | `kz_hikari_od` | Starting map (downloaded from `sm_dlmap_url` if missing) |
| `MAPCMD` | `map` | Command used to load the starting map (e.g., `host_workshop_map`) |
| `MAXPLAYERS` | `10` | Player slots |
| `PORT` | `27015` | Game port (TCP and UDP) |
| `SERVERCFG` | `server.cfg` | Server config file in `csgo/cfg` |
| `FLAGS` | | Extra srcds command-line options (e.g., `-nomaster`) |
| `MAPPOOL` | badservers.net map pool | GOKZ local ranks map pool (empty to skip) |

### API keys

Keys go in files on the data volume, so they never appear in your compose file
or `docker inspect`. Each file holds just the key on one line:

| Key | File (paths from the [example](#example-composeyaml)) |
| --- | --- |
| GOKZ global API key | `gokz/etc/cfg/sourcemod/globalapi-key.cfg` |
| Steam Web API key (only needed to load workshop maps) | `gokz/data/csgo/webapi_authkey.txt` |

Without the config mount, the first one is
`gokz/data/csgo/cfg/sourcemod/globalapi-key.cfg`. Create them with an editor
(not `echo`, which leaves the key in your shell history), make them readable
only by the server, and restart the container:

```sh
chmod 600 gokz/etc/cfg/sourcemod/globalapi-key.cfg gokz/data/csgo/webapi_authkey.txt
sudo chown 1000:1000 gokz/etc/cfg/sourcemod/globalapi-key.cfg gokz/data/csgo/webapi_authkey.txt  # skip on rootless Docker
```

### Config files

Default configs are copied in on the first start and after each update, but
only when they don't exist yet.

To turn off a bundled plugin, move it into `addons/sourcemod/plugins/disabled/`.
It stays disabled across updates.

## Updating

Rebuild the image and recreate the container:

```sh
docker compose build --pull gokz
docker compose up -d gokz
```

Plugins and other bundled files are updated on the next start. Your configs
are left alone.

## Maps

The optional `gokz-maps` container downloads any maps from the
[KZ map archive](https://csgo-kz-maps.badservers.net) that you don't have yet,
every day at 4:00 local time. Maps you already have, including ones from
other sources, are never touched. The full archive is large, so check your
free disk space before enabling it.

Example `compose.yaml`:

```yaml
  gokz-maps:
    container_name: gokz-maps
    restart: unless-stopped
    cpus: 0.5
    build: ./gokz-docker/maps
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./gokz/data/csgo/maps:/data/csgo/maps
```

The container only gets the maps directory, so it can't touch plugins or
configs. The setup commands above create it; if you skipped them, create it
before starting this service.

Run a sync right away:

```sh
docker exec gokz-maps /maps.sh
```

Delete maps that fail their checksum, so the next sync downloads them again:

```sh
docker exec gokz-maps /maps.sh verify
```

## Crash dumps

When srcds crashes, the next start moves the crash dump into
`gokz/data/crashdumps/`. Each `.dmp` has a `.dmp.txt` next to it with the map,
command line, and recent console output, which often points at the culprit.
Nothing is uploaded anywhere.

To see the stack traces, use
[minidump-stackwalk](https://github.com/rust-minidump/rust-minidump/tree/main/minidump-stackwalk):

```sh
cargo install minidump-stackwalk
minidump-stackwalk gokz/data/crashdumps/<file>.dmp
```

Frames show up as module and offset (e.g. `server.so + 0x1a2b3c`). Plugin
(SourcePawn) frames aren't named. Dumps contain the server's memory, including
your API keys, so don't share them publicly.

## Permissions

Both containers run as 1000:1000 and never as root, so they can't fix
ownership for you. Every directory you mount, and every mount point inside
`gokz/data`, has to exist and be writable by that user before the first start
(the `mkdir` and `chown` in the [example](#example-composeyaml)). If Docker
creates a missing one itself, root owns it and the server can't write to it.

- **Different owner:** set `user: "UID:GID"` on both services to the owner of
  your data directory.
- **Rootless Docker:** set `user: "0:0"` on both services and skip the `chown`.
  Root inside the container is your own user on the host, so it owns your files
  without needing any capabilities, and `cap_drop: [ALL]` still applies.
- **`userns-remap`:** add `userns_mode: host` to both services, or chown your
  data directories to the remapped UID (the start of your subordinate UID range
  plus 1000).
- **Upgrading from `PUID`/`PGID`:** they're gone. If you set them to something
  other than 1000, use `user:` instead; if you set them to `0` for rootless
  Docker, use `user: "0:0"`.

## GOKZ build

The image bundles
[GOKZ 3.6.4-srs1](https://github.com/misscatmint/gokz/releases/tag/3.6.4-srs1)
along with the SteamWorks and GlobalAPI versions it needs. Each one is a build
argument, so you can swap in another release or your own fork.

### GOKZ 3.7.x

GOKZ 3.7.x needs newer SteamWorks and GlobalAPI builds. Set all of these
arguments together:

```yaml
  gokz:
    build:
      context: ./gokz-docker
      args:
        GOKZ: https://github.com/misscatmint/gokz/releases/download/3.7.0-srs1/GOKZ-v3.7.0-srs1.zip
        GOKZ_SHA256: 645ac99dfadcb45a347b5c617f1db9709105fa36a7c53bfb84d19334a945d587
        STEAMWORKS: https://github.com/alliedmodders/SM-SteamWorks/releases/download/v1.2.167/SteamWorks-1.2.167-sm1.12-linux.tar.gz
        STEAMWORKS_SHA256: af5d01b170b866f9e377d3739bded46138044cc54fb7c381ba77d34e07bb783c
        STEAMWORKS_PREFIX: ""
        GLOBALAPI: https://github.com/misscatmint/csgo-sm-globalapi/releases/download/v2.1.0/GlobalAPI-v2.1.0.zip
        GLOBALAPI_SHA256: a7f16bb752ba836916e016e291fde41beaf1fe0022fb2d0032cc488ffe7cf72b
```

`STEAMWORKS_PREFIX` is the folder the SteamWorks archive keeps its files in:
`package` for the default build, and empty for the one above. If you leave it
out, the build fails with `package/addons/sourcemod/extensions: Not found in
archive`.

### Notes

The GOKZ zip must have the same layout as an official GOKZ release. Every URL
needs its matching `_SHA256` (get it with `curl -fsSL URL | sha256sum`), and the
build fails if the download doesn't match, so point them at one fixed release.
Downgrading on an existing `/data` volume isn't guaranteed to work.
